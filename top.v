`timescale 1ns / 100ps

module red_pitaya (
  input wire [1:1] adc_clk_i,
  //Debug LEDs
  output reg[7:0] led_o
);

  reg [24:0] counter;

  assign led_o = counter[24:17];

  always @(posedge adc_clk_i[1]) begin
    counter <= counter + 1;
  end
endmodule

