const cpu = @import("cpu.zig");
const CPU = cpu.CPU;

const Computer = struct {
    cpu: CPU,

    fn init() Computer {
        return Computer{
            .cpu = CPU.init(),
        };
    }
};
