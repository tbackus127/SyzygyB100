`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/08/2017 10:28:14 PM
// Design Name: 
// Module Name: ClockDivider
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ClockDivider(
    input cIn,
    output cOut
  );
  
  reg [31:0] counter;
  
  always @ (posedge cIn) begin
    counter <= counter + 1;
  end
  
  // Stable at 3
  assign cOut = counter[5];
  
endmodule
