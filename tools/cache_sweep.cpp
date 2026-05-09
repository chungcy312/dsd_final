#include <algorithm>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

using u32 = uint32_t;
using i32 = int32_t;
using u64 = uint64_t;

static constexpr u32 kDoneInst = 0x00202007u;
static constexpr int kLineBytes = 16;  // slow memory interface is fixed at 128-bit.
static constexpr double kAvgSlowMemDelayNs = 45.0; // random latency: 40..50 ns

struct AccessStat {
    u64 access = 0;
    u64 miss = 0;
    u64 writeback = 0;
};

struct CacheLine {
    bool valid = false;
    bool dirty = false;
    u32 tag = 0;
    u64 age = 0;
};

class Cache {
public:
    Cache(int blocks, int ways) : blocks_(blocks), ways_(ways), sets_(blocks / ways), lines_(sets_) {
        for (auto &set : lines_) set.resize(ways_);
    }

    void access(u32 addr, bool write, AccessStat &stat) {
        stat.access++;
        u32 line_addr = addr / kLineBytes;
        int set = static_cast<int>(line_addr % sets_);
        u32 tag = line_addr / sets_;
        tick_++;

        for (auto &line : lines_[set]) {
            if (line.valid && line.tag == tag) {
                line.age = tick_;
                if (write) line.dirty = true;
                return;
            }
        }

        stat.miss++;
        int victim = 0;
        for (int w = 0; w < ways_; ++w) {
            if (!lines_[set][w].valid) {
                victim = w;
                goto replace;
            }
            if (lines_[set][w].age < lines_[set][victim].age) victim = w;
        }

    replace:
        if (lines_[set][victim].valid && lines_[set][victim].dirty) stat.writeback++;
        lines_[set][victim].valid = true;
        lines_[set][victim].dirty = write;
        lines_[set][victim].tag = tag;
        lines_[set][victim].age = tick_;
    }

    int sets() const { return sets_; }

private:
    int blocks_;
    int ways_;
    int sets_;
    u64 tick_ = 0;
    std::vector<std::vector<CacheLine>> lines_;
};

static std::string trim(std::string s) {
    auto not_space = [](unsigned char c) { return !std::isspace(c); };
    s.erase(s.begin(), std::find_if(s.begin(), s.end(), not_space));
    s.erase(std::find_if(s.rbegin(), s.rend(), not_space).base(), s.end());
    return s;
}

static bool parse_hex_bytes(const std::string &line, u32 &word) {
    std::string s = line.substr(0, line.find("//"));
    s = trim(s);
    if (s.empty()) return false;

    std::vector<unsigned> bytes;
    std::stringstream ss(s);
    std::string part;
    while (std::getline(ss, part, '_')) {
        part = trim(part);
        if (part.empty()) continue;
        unsigned value = 0;
        std::stringstream hs;
        hs << std::hex << part;
        hs >> value;
        if (hs.fail()) return false;
        bytes.push_back(value & 0xffu);
    }
    if (bytes.size() != 4) return false;
    word = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
    return true;
}

static std::vector<u32> load_words(const std::string &path) {
    std::ifstream in(path);
    std::vector<u32> words;
    std::string line;
    while (std::getline(in, line)) {
        u32 word = 0;
        if (parse_hex_bytes(line, word)) words.push_back(word);
    }
    return words;
}

struct Cpu {
    std::vector<u32> imem;
    std::unordered_map<u32, u32> dmem;
    u32 reg[32] = {};
    u32 pc = 0;
    u64 instrs = 0;
    bool done = false;

    std::vector<u32> ifetch_trace;
    std::vector<std::pair<u32, bool>> dmem_trace; // bool=true for store

    u32 load_word(u32 addr) const {
        auto it = dmem.find(addr & ~3u);
        return it == dmem.end() ? 0u : it->second;
    }

    void store_word(u32 addr, u32 value) { dmem[addr & ~3u] = value; }

    static i32 sext(u32 v, int bits) {
        u32 mask = 1u << (bits - 1);
        return static_cast<i32>((v ^ mask) - mask);
    }

    void step() {
        if (pc / 4 >= imem.size()) {
            done = true;
            return;
        }
        u32 inst = imem[pc / 4];
        ifetch_trace.push_back(pc);
        instrs++;
        if (inst == kDoneInst) {
            done = true;
            return;
        }

        u32 opcode = inst & 0x7f;
        u32 rd = (inst >> 7) & 0x1f;
        u32 funct3 = (inst >> 12) & 0x7;
        u32 rs1 = (inst >> 15) & 0x1f;
        u32 rs2 = (inst >> 20) & 0x1f;
        u32 funct7 = (inst >> 25) & 0x7f;
        u32 next_pc = pc + 4;

        auto write_rd = [&](u32 value) {
            if (rd != 0) reg[rd] = value;
        };

        switch (opcode) {
        case 0x37: { // LUI
            write_rd(inst & 0xfffff000u);
            break;
        }
        case 0x17: { // AUIPC
            write_rd(pc + (inst & 0xfffff000u));
            break;
        }
        case 0x6f: { // JAL
            i32 imm = sext(((inst >> 31) << 20) |
                               (((inst >> 12) & 0xff) << 12) |
                               (((inst >> 20) & 1) << 11) |
                               (((inst >> 21) & 0x3ff) << 1),
                           21);
            write_rd(pc + 4);
            next_pc = pc + imm;
            break;
        }
        case 0x67: { // JALR
            i32 imm = sext(inst >> 20, 12);
            write_rd(pc + 4);
            next_pc = (reg[rs1] + imm) & ~1u;
            break;
        }
        case 0x63: { // branch
            i32 imm = sext(((inst >> 31) << 12) |
                               (((inst >> 7) & 1) << 11) |
                               (((inst >> 25) & 0x3f) << 5) |
                               (((inst >> 8) & 0xf) << 1),
                           13);
            bool take = false;
            if (funct3 == 0x0) take = reg[rs1] == reg[rs2];
            if (funct3 == 0x1) take = reg[rs1] != reg[rs2];
            if (take) next_pc = pc + imm;
            break;
        }
        case 0x03: { // load, model all as word-aligned cache access
            i32 imm = sext(inst >> 20, 12);
            u32 addr = reg[rs1] + imm;
            dmem_trace.push_back({addr, false});
            write_rd(load_word(addr));
            break;
        }
        case 0x23: { // store
            i32 imm = sext(((inst >> 25) << 5) | ((inst >> 7) & 0x1f), 12);
            u32 addr = reg[rs1] + imm;
            dmem_trace.push_back({addr, true});
            store_word(addr, reg[rs2]);
            break;
        }
        case 0x13: { // I-type ALU
            i32 imm = sext(inst >> 20, 12);
            u32 shamt = (inst >> 20) & 0x1f;
            switch (funct3) {
            case 0x0: write_rd(reg[rs1] + imm); break;
            case 0x2: write_rd(static_cast<i32>(reg[rs1]) < imm); break;
            case 0x4: write_rd(reg[rs1] ^ static_cast<u32>(imm)); break;
            case 0x6: write_rd(reg[rs1] | static_cast<u32>(imm)); break;
            case 0x7: write_rd(reg[rs1] & static_cast<u32>(imm)); break;
            case 0x1: write_rd(reg[rs1] << shamt); break;
            case 0x5:
                write_rd((funct7 == 0x20) ? static_cast<u32>(static_cast<i32>(reg[rs1]) >> shamt)
                                          : (reg[rs1] >> shamt));
                break;
            }
            break;
        }
        case 0x33: { // R-type ALU
            switch (funct3) {
            case 0x0: write_rd((funct7 == 0x20) ? reg[rs1] - reg[rs2] : reg[rs1] + reg[rs2]); break;
            case 0x1: write_rd(reg[rs1] << (reg[rs2] & 0x1f)); break;
            case 0x2: write_rd(static_cast<i32>(reg[rs1]) < static_cast<i32>(reg[rs2])); break;
            case 0x4: write_rd(reg[rs1] ^ reg[rs2]); break;
            case 0x5:
                write_rd((funct7 == 0x20) ? static_cast<u32>(static_cast<i32>(reg[rs1]) >> (reg[rs2] & 0x1f))
                                          : (reg[rs1] >> (reg[rs2] & 0x1f)));
                break;
            case 0x6: write_rd(reg[rs1] | reg[rs2]); break;
            case 0x7: write_rd(reg[rs1] & reg[rs2]); break;
            }
            break;
        }
        default:
            std::cerr << "Unsupported opcode 0x" << std::hex << opcode
                      << " at pc 0x" << pc << ", inst 0x" << inst << std::dec << "\n";
            done = true;
            break;
        }

        reg[0] = 0;
        pc = next_pc;
    }
};

struct Pattern {
    std::string name;
    std::string imem;
    std::string dmem;
};

static void run_pattern(const Pattern &p) {
    auto iwords = load_words(p.imem);
    auto dwords = load_words(p.dmem);
    if (iwords.empty()) {
        std::cerr << "[skip] missing/empty I_mem for " << p.name << ": " << p.imem << "\n";
        return;
    }

    Cpu cpu;
    cpu.imem = std::move(iwords);
    for (size_t i = 0; i < dwords.size(); ++i) cpu.dmem[static_cast<u32>(i * 4)] = dwords[i];

    constexpr u64 kMaxInstr = 20000000;
    while (!cpu.done && cpu.instrs < kMaxInstr) cpu.step();
    if (!cpu.done) {
        std::cerr << "[warn] " << p.name << " did not reach done instruction within "
                  << kMaxInstr << " instructions\n";
    }

    std::cout << "\n=== " << p.name << " ===\n";
    std::cout << "dynamic instructions: " << cpu.instrs
              << ", I accesses: " << cpu.ifetch_trace.size()
              << ", D accesses: " << cpu.dmem_trace.size() << "\n";
    std::cout << "blocks,ways,sets,I_miss_rate,D_miss_rate,total_misses,writebacks,expected_mem_delay_ns\n";

    const int blocks_list[] = {8, 16, 32, 64, 128};
    const int ways_list[] = {1, 2, 4, 8, 16};
    for (int blocks : blocks_list) {
        for (int ways : ways_list) {
            if (ways > blocks || blocks % ways != 0) continue;
            Cache ic(blocks, ways), dc(blocks, ways);
            AccessStat is, ds;
            for (u32 addr : cpu.ifetch_trace) ic.access(addr, false, is);
            for (auto [addr, wr] : cpu.dmem_trace) dc.access(addr, wr, ds);
            u64 total_mem_tx = is.miss + ds.miss + ds.writeback;
            double expected_delay = total_mem_tx * kAvgSlowMemDelayNs;
            double imr = is.access ? static_cast<double>(is.miss) / is.access : 0.0;
            double dmr = ds.access ? static_cast<double>(ds.miss) / ds.access : 0.0;
            std::cout << blocks << ',' << ways << ',' << (blocks / ways) << ','
                      << std::fixed << std::setprecision(6) << imr << ','
                      << dmr << ',' << (is.miss + ds.miss) << ','
                      << ds.writeback << ',' << std::setprecision(1) << expected_delay << "\n";
        }
    }
}

int main(int argc, char **argv) {
    std::string root = (argc >= 2) ? argv[1] : ".";
    std::vector<Pattern> patterns = {
        {"QSort", root + "/00_TESTBED/pattern/Q_Sort/I_mem", root + "/00_TESTBED/pattern/Q_Sort/D_mem"},
        {"Conv", root + "/00_TESTBED/pattern/Conv/I_mem", root + "/00_TESTBED/pattern/Conv/D_mem"},
        {"LFSR_HIST", root + "/00_TESTBED/pattern/LFSR_HIST/I_mem", root + "/00_TESTBED/pattern/LFSR_HIST/D_mem"},
    };
    for (const auto &p : patterns) run_pattern(p);
    return 0;
}
