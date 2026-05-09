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
    u64 jumps = 0;

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
        case 0x37: // LUI
            write_rd(inst & 0xfffff000u);
            break;
        case 0x17: // AUIPC
            write_rd(pc + (inst & 0xfffff000u));
            break;
        case 0x6f: { // JAL
            i32 imm = sext(((inst >> 31) << 20) |
                               (((inst >> 12) & 0xff) << 12) |
                               (((inst >> 20) & 1) << 11) |
                               (((inst >> 21) & 0x3ff) << 1),
                           21);
            write_rd(pc + 4);
            next_pc = pc + imm;
            jumps++;
            break;
        }
        case 0x67: { // JALR
            i32 imm = sext(inst >> 20, 12);
            write_rd(pc + 4);
            next_pc = (reg[rs1] + imm) & ~1u;
            jumps++;
            break;
        }
        case 0x63: { // conditional branch
            i32 imm = sext(((inst >> 31) << 12) |
                               (((inst >> 7) & 1) << 11) |
                               (((inst >> 25) & 0x3f) << 5) |
                               (((inst >> 8) & 0xf) << 1),
                           13);
            bool take = false;
            switch (funct3) {
            case 0x0: take = reg[rs1] == reg[rs2]; break; // BEQ
            case 0x1: take = reg[rs1] != reg[rs2]; break; // BNE
            case 0x4: take = static_cast<i32>(reg[rs1]) < static_cast<i32>(reg[rs2]); break; // BLT
            case 0x5: take = static_cast<i32>(reg[rs1]) >= static_cast<i32>(reg[rs2]); break; // BGE
            case 0x6: take = reg[rs1] < reg[rs2]; break; // BLTU
            case 0x7: take = reg[rs1] >= reg[rs2]; break; // BGEU
            }
            branches.push_back({pc, take});
            if (take) next_pc = pc + imm;
            break;
        }
        case 0x03: { // load
            i32 imm = sext(inst >> 20, 12);
            write_rd(load_word(reg[rs1] + imm));
            break;
        }
        case 0x23: { // store
            i32 imm = sext(((inst >> 25) << 5) | ((inst >> 7) & 0x1f), 12);
            store_word(reg[rs1] + imm, reg[rs2]);
            break;
        }
        case 0x13: { // I-type ALU
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
        case 0x33: { // R-type ALU
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

struct PredictStat {
    u64 branches = 0;
    u64 correct = 0;
};

class BimodalPredictor {
public:
    BimodalPredictor(int counter_bits, int entries, int init_state = -1)
        : bits_(counter_bits),
          entries_(entries),
          max_value_((1u << counter_bits) - 1u),
          threshold_(1u << (counter_bits - 1)),
          table_(entries, initial_value(counter_bits, init_state)) {}

    bool predict(u32 pc) const {
        return table_[index(pc)] >= threshold_;
    }

    void update(u32 pc, bool taken) {
        u32 &counter = table_[index(pc)];
        if (taken) {
            if (counter < max_value_) counter++;
        } else if (counter > 0) {
            counter--;
        }
    }

private:
    static u32 initial_value(int bits, int init_state) {
        if (init_state >= 0) return static_cast<u32>(init_state);
        if (bits == 1) return 0;       // predict not taken initially
        return (1u << (bits - 1)) - 1; // weakly not taken
    }

    int index(u32 pc) const {
        return static_cast<int>((pc >> 2) & (entries_ - 1));
    }

    int bits_;
    int entries_;
    u32 max_value_;
    u32 threshold_;
    std::vector<u32> table_;
};

static PredictStat simulate_bimodal(const std::vector<BranchEvent> &trace,
                                     int counter_bits,
                                     int entries,
                                     int init_state) {
    BimodalPredictor pred(counter_bits, entries, init_state);
    PredictStat stat;
    for (const auto &br : trace) {
        bool guess = pred.predict(br.pc);
        stat.branches++;
        if (guess == br.taken) stat.correct++;
        pred.update(br.pc, br.taken);
    }
    return stat;
}

static double accuracy(const PredictStat &s) {
    return s.branches ? static_cast<double>(s.correct) / s.branches : 0.0;
}

static std::vector<BranchEvent> build_trace(const Pattern &p) {
    auto iwords = load_words(p.imem);
    auto dwords = load_words(p.dmem);
    if (iwords.empty()) {
        std::cerr << "[skip] missing/empty I_mem for " << p.name << ": " << p.imem << "\n";
        return {};
    }

    Cpu cpu;
    cpu.imem = std::move(iwords);
    for (size_t i = 0; i < dwords.size(); ++i) {
        cpu.dmem[static_cast<u32>(i * 4)] = dwords[i];
    }

    constexpr u64 kMaxInstr = 20000000;
    while (!cpu.done && cpu.instrs < kMaxInstr) cpu.step();
    if (!cpu.done) {
        std::cerr << "[warn] " << p.name << " did not reach done instruction within "
                  << kMaxInstr << " instructions\n";
    }

    std::cerr << "[trace] " << p.name
              << ": instructions=" << cpu.instrs
              << ", conditional_branches=" << cpu.branches.size()
              << ", jumps=" << cpu.jumps << "\n";
    return cpu.branches;
}

int main(int argc, char **argv) {
    std::string root = (argc >= 2) ? argv[1] : ".";
    int entries = (argc >= 3) ? std::stoi(argv[2]) : 256;
    int max_bits = (argc >= 4) ? std::stoi(argv[3]) : 6;

    if (entries <= 0 || (entries & (entries - 1)) != 0) {
        std::cerr << "entries must be power of two\n";
        return 1;
    }
    if (max_bits < 1 || max_bits > 12) {
        std::cerr << "max_bits must be 1..12\n";
        return 1;
    }

    std::vector<Pattern> patterns = {
        {"QSort", root + "/00_TESTBED/pattern/Q_Sort/I_mem", root + "/00_TESTBED/pattern/Q_Sort/D_mem"},
        {"Conv", root + "/00_TESTBED/pattern/Conv/I_mem", root + "/00_TESTBED/pattern/Conv/D_mem"},
        {"LFSR_HIST", root + "/00_TESTBED/pattern/LFSR_HIST/I_mem", root + "/00_TESTBED/pattern/LFSR_HIST/D_mem"},
    };

    std::cout << "pattern,entries,counter_bits,init_state,init_prediction,branches,correct,accuracy,miss_rate\n";
    for (const auto &p : patterns) {
        auto trace = build_trace(p);
        if (trace.empty()) continue;
        for (int bits = 1; bits <= max_bits; ++bits) {
            int max_state = (1 << bits) - 1;
            int threshold = 1 << (bits - 1);
            for (int init = 0; init <= max_state; ++init) {
                PredictStat stat = simulate_bimodal(trace, bits, entries, init);
                double acc = accuracy(stat);
                std::cout << p.name << ','
                          << entries << ','
                          << bits << ','
                          << init << ','
                          << ((init >= threshold) ? "T" : "N") << ','
                          << stat.branches << ','
                          << stat.correct << ','
                          << std::fixed << std::setprecision(6) << acc << ','
                          << (1.0 - acc) << "\n";
            }
        }
    }

    return 0;
}
