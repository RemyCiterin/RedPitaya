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

