`include "defines.vh"
module regfile_HILO(
    input wire clk,
    input wire HI_we,
    input wire LO_we,  
    input wire[31:0]HIwdata,
    input wire[31:0]LOwdata,
    output wire[31:0]HIrdata,
    output wire[31:0]LOrdata
);   
    reg [31:0]rf_HI;
    reg [31:0]rf_LO;
    always @ (posedge clk) begin
        if (LO_we) begin
           rf_LO <= LOwdata;
        end
        if (HI_we) begin
            rf_HI <=HIwdata;
        end
    end
    
    assign HIrdata = rf_LO;
    assign LOrdata = rf_HI;
endmodule
