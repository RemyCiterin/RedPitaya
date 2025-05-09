# RedPitaya

Test of the red pitaya board with yosys and nextpnr (no Vivado)

## Program the FPGA

To program the Zynq7 FPGA inside the RedPitaya, write your design in `top.v`. You must define
an instance of `PS7` to use the dual-core ARM cpu, otherwise you will observe a crash follow
by a reboot of the board. As example my default program is:

```verilog
`timescale 1ns / 100ps

module red_pitaya (
  input wire [1:1] adc_clk_i,
  output wire[7:0] led_o
);

  reg [32:0] counter;
  assign led_o = counter[31:24];

  always @(posedge adc_clk_i[1]) begin
    counter <= counter + 1;
  end

  PS7 zynq7();
endmodule
```

Then one can generate the bitstream using: 

```bash
nix develop github:openxc7/toolchain-nix
mkdir build db
make yosys all
```

Then we need to upload the bitstream into the RedPitaya (with an OS version < 2.0):

```bash
scp build/red_pitaya.bit root@rp-xxxxxx.local:/root
ssh root@rp-xxxxxx.local
cat ./red_pitaya.bit > /dev/xdevcfg
```

 with `xxxxxx` the last 6 digits of the MAC address on the Ethernet connector. The default password of the board is 
 `root`.
