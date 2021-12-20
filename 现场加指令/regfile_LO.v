`include "defines.vh"
module regfile_LO(
    input wire clk,
    input wire LO_we,
    input wire[31:0]wdata,
    
    output wire[31:0] rdata
);   
    reg [31:0]rf_LO;
    always @ (posedge clk) begin
        if (LO_we) begin
           rf_LO <= wdata;
        end
    end
    
    assign rdata = rf_LO;
endmodule
