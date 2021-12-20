`include "defines.vh"
module regfile_HI(
    input wire clk,
    input wire HI_we,
    input wire[31:0] wdata,
    
    output wire[31:0] rdata
);
    reg[31:0] rf_HI;
    always @ (posedge clk) begin
        if (HI_we) begin
           rf_HI <= wdata;
        end
    end
    
    assign rdata = rf_HI;
endmodule
