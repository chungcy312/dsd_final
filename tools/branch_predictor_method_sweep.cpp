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

struct BranchEvent {
    u32 pc = 0;
    u32 target = 0;
    bool taken = false;
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
    std::vector<BranchEvent> branches;

    u32 load_word(u32 addr) const {
        auto it = dmem.find(addr & ~3u);
        return it == dmem.end() ? 0u : it->second;
    }

    void store_word(u32 addr, u32 value) {
        dmem[addr & ~3u] = value;
    }

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
        case 0x37: write_rd(inst & 0xfffff000u); break;
        case 0x17: write_rd(pc + (inst & 0xfffff000u)); break;
        case 0x6f: {
            i32 imm = sext(((inst >> 31) << 20) |
                               (((inst >> 12) & 0xff) << 12) |
                               (((inst >> 20) & 1) << 11) |
                               (((inst >> 21) & 0x3ff) << 1),
                           21);
            write_rd(pc + 4);
            next_pc = pc + imm;
            break;
        }
        case 0x67: {
            i32 imm = sext(inst >> 20, 12);
            write_rd(pc + 4);
            next_pc = (reg[rs1] + imm) & ~1u;
            break;
        }
        case 0x63: {
            i32 imm = sext(((inst >> 31) << 12) |
                               (((inst >> 7) & 1) << 11) |
                               (((inst >> 25) & 0x3f) << 5) |
                               (((inst >> 8) & 0xf) << 1),
                           13);
            bool take = false;
            switch (funct3) {
            case 0x0: take = reg[rs1] == reg[rs2]; break;
            case 0x1: take = reg[rs1] != reg[rs2]; break;
            case 0x4: take = static_cast<i32>(reg[rs1]) < static_cast<i32>(reg[rs2]); break;
            case 0x5: take = static_cast<i32>(reg[rs1]) >= static_cast<i32>(reg[rs2]); break;
            case 0x6: take = reg[rs1] < reg[rs2]; break;
            case 0x7: take = reg[rs1] >= reg[rs2]; break;
            }
            u32 target = pc + imm;
            branches.push_back({pc, target, take});
            if (take) next_pc = target;
            break;
        }
        case 0x03: {
            i32 imm = sext(inst >> 20, 12);
            write_rd(load_word(reg[rs1] + imm));
            break;
        }
        case 0x23: {
            i32 imm = sext(((inst >> 25) << 5) | ((inst >> 7) & 0x1f), 12);
            store_word(reg[rs1] + imm, reg[rs2]);
            break;
        }
        case 0x13: {
            i32 imm = sext(inst >> 20, 12);
            u32 shamt = (inst >> 20) & 0x1f;
            switch (funct3) {
            case 0x0: write_rd(reg[rs1] + imm); break;
            case 0x2: write_rd(static_cast<i32>(reg[rs1]) < imm); break;
            case 0x3: write_rd(reg[rs1] < static_cast<u32>(imm)); break;
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
        case 0x33: {
            switch (funct3) {
            case 0x0: write_rd((funct7 == 0x20) ? reg[rs1] - reg[rs2] : reg[rs1] + reg[rs2]); break;
            case 0x1: write_rd(reg[rs1] << (reg[rs2] & 0x1f)); break;
            case 0x2: write_rd(static_cast<i32>(reg[rs1]) < static_cast<i32>(reg[rs2])); break;
            case 0x3: write_rd(reg[rs1] < reg[rs2]); break;
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

struct Stat {
    u64 branches = 0;
    u64 correct = 0;
};

static double acc(const Stat &s) {
    return s.branches ? static_cast<double>(s.correct) / s.branches : 0.0;
}

static std::vector<BranchEvent> build_trace(const Pattern &p) {
    auto iwords = load_words(p.imem);
    auto dwords = load_words(p.dmem);
    Cpu cpu;
    cpu.imem = std::move(iwords);
    for (size_t i = 0; i < dwords.size(); ++i) {
        cpu.dmem[static_cast<u32>(i * 4)] = dwords[i];
    }
    constexpr u64 kMaxInstr = 20000000;
    while (!cpu.done && cpu.instrs < kMaxInstr) cpu.step();
    std::cerr << "[trace] " << p.name
              << ": instructions=" << cpu.instrs
              << ", conditional_branches=" << cpu.branches.size() << "\n";
    return cpu.branches;
}

static Stat always_predict(const std::vector<BranchEvent> &trace, bool taken) {
    Stat s;
    for (const auto &b : trace) {
        s.branches++;
        if (taken == b.taken) s.correct++;
    }
    return s;
}

static Stat btfnt(const std::vector<BranchEvent> &trace) {
    Stat s;
    for (const auto &b : trace) {
        bool pred = b.target < b.pc;
        s.branches++;
        if (pred == b.taken) s.correct++;
    }
    return s;
}

class CounterTable {
public:
    CounterTable(int entries, int bits, int init)
        : entries_(entries),
          bits_(bits),
          max_((1u << bits) - 1u),
          threshold_(1u << (bits - 1)),
          table_(entries, static_cast<u32>(init)) {}

    bool predict_index(int idx) const {
        return table_[idx] >= threshold_;
    }

    void update_index(int idx, bool taken) {
        u32 &c = table_[idx];
        if (taken) {
            if (c < max_) c++;
        } else if (c > 0) {
            c--;
        }
    }

private:
    int entries_;
    int bits_;
    u32 max_;
    u32 threshold_;
    std::vector<u32> table_;
};

static Stat bimodal(const std::vector<BranchEvent> &trace, int entries, int bits, int init) {
    CounterTable p(entries, bits, init);
    Stat s;
    for (const auto &b : trace) {
        int idx = static_cast<int>((b.pc >> 2) & (entries - 1));
        bool pred = p.predict_index(idx);
        s.branches++;
        if (pred == b.taken) s.correct++;
        p.update_index(idx, b.taken);
    }
    return s;
}

static Stat gshare(const std::vector<BranchEvent> &trace, int entries, int bits, int init, int history_bits) {
    CounterTable p(entries, bits, init);
    u32 history = 0;
    u32 history_mask = (history_bits == 32) ? 0xffffffffu : ((1u << history_bits) - 1u);
    Stat s;
    for (const auto &b : trace) {
        int pc_idx = static_cast<int>((b.pc >> 2) & (entries - 1));
        int idx = (pc_idx ^ static_cast<int>(history & (entries - 1))) & (entries - 1);
        bool pred = p.predict_index(idx);
        s.branches++;
        if (pred == b.taken) s.correct++;
        p.update_index(idx, b.taken);
        history = ((history << 1) | (b.taken ? 1u : 0u)) & history_mask;
    }
    return s;
}

static void print_result(const std::string &pattern, const std::string &method,
                         int entries, int bits, int init, int history_bits, const Stat &s) {
    std::cout << pattern << ','
              << method << ','
              << entries << ','
              << bits << ','
              << init << ','
              << history_bits << ','
              << s.branches << ','
              << s.correct << ','
              << std::fixed << std::setprecision(6) << acc(s) << ','
              << (1.0 - acc(s)) << "\n";
}

int main(int argc, char **argv) {
    std::string root = (argc >= 2) ? argv[1] : ".";
    std::vector<Pattern> patterns = {
        {"BrPred", root + "/00_TESTBED/pattern/BrPred/I_mem_BrPred", root + "/00_TESTBED/pattern/BrPred/D_mem"},
        {"QSort", root + "/00_TESTBED/pattern/Q_Sort/I_mem", root + "/00_TESTBED/pattern/Q_Sort/D_mem"},
        {"Conv", root + "/00_TESTBED/pattern/Conv/I_mem", root + "/00_TESTBED/pattern/Conv/D_mem"},
        {"LFSR_HIST", root + "/00_TESTBED/pattern/LFSR_HIST/I_mem", root + "/00_TESTBED/pattern/LFSR_HIST/D_mem"},
    };

    std::cout << "pattern,method,entries,counter_bits,init_state,history_bits,branches,correct,accuracy,miss_rate\n";
    for (const auto &p : patterns) {
        auto trace = build_trace(p);
        print_result(p.name, "always_nt", 0, 0, 0, 0, always_predict(trace, false));
        print_result(p.name, "always_t", 0, 0, 0, 0, always_predict(trace, true));
        print_result(p.name, "btfnt", 0, 0, 0, 0, btfnt(trace));

        for (int bits : {2, 3}) {
            int init = (bits == 2) ? 0 : 2;
            print_result(p.name, "global_counter", 1, bits, init, 0, bimodal(trace, 1, bits, init));
            for (int entries : {4, 8, 16, 32, 64, 128, 256}) {
                print_result(p.name, "bimodal", entries, bits, init, 0, bimodal(trace, entries, bits, init));
                for (int hist : {2, 4, 6, 8}) {
                    if (hist > 0 && hist <= 16) {
                        print_result(p.name, "gshare", entries, bits, init, hist,
                                     gshare(trace, entries, bits, init, hist));
                    }
                }
            }
        }
    }
    return 0;
}
