`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0]data_sram_rdata,

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    
    output wire [`MEM_TO_RF_WD-1:0]mem_to_rf_bus
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
    end

    wire [31:0] mem_pc;
    wire data_ram_en;
    wire [3:0] data_ram_sel_id;
    wire [3:0] data_ram_sel_ex;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0]  rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;

    assign {
        data_ram_sel_id,
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_sel_ex,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } =  ex_to_mem_bus_r;
    
    wire [15:0] data_ram_half;
    wire [7:0] data_ram_byte;
    
    assign data_ram_half = (data_ram_sel_ex == 4'b1100) ? data_sram_rdata[31:16] : data_sram_rdata[15:0];
    assign data_ram_byte = (data_ram_sel_ex == 4'b1000) ? data_sram_rdata[31:24] : 
                           (data_ram_sel_ex == 4'b0100) ? data_sram_rdata[23:16] : 
                           (data_ram_sel_ex == 4'b0010) ? data_sram_rdata[15:8] :
                           data_sram_rdata[7:0];
    assign mem_result = ({32{data_ram_sel_id[0]}} & data_sram_rdata) | 
                        ({32{data_ram_sel_id[1]}} & {{16{data_ram_sel_id[3]}} & {16{data_ram_half[15]}},data_ram_half})|
                        ({32{data_ram_sel_id[2]}} & {{24{data_ram_sel_id[3]}} & {24{data_ram_byte[7]}} ,data_ram_byte});



    assign rf_wdata = sel_rf_res ? mem_result : ex_result;
    
    assign mem_to_rf_bus = {
        rf_we,
        rf_waddr,
        rf_wdata
    };

    assign mem_to_wb_bus = {
        mem_pc,     // 41:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };




endmodule