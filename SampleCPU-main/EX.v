`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    
    
    output wire [`EX_TO_RF_WD-1:0]ex_to_rf_bus,
    output wire [5:0] ex_opcode,
    output wire stallreq_for_ex
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire data_ram_wen;
    wire [3:0]data_ram_sel_id;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;
    wire inst_div, inst_divu,inst_mult,inst_multu,inst_mthi,inst_mtlo,inst_mfhi,inst_mflo;
    
    assign {
        data_ram_wen,
        inst_div,
        inst_divu,
        inst_mult,
        inst_multu,
        inst_mfhi,
        inst_mflo,
        inst_mthi,
        inst_mtlo,
        ex_pc,          // 148:117
        inst,           // 116:85
        alu_op,         // 84:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_sel_id,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;
    
    wire HI_we,LO_we;
    wire[31:0] HIdata,LOdata,HI_rf_data,LO_rf_data;
    
    regfile_HILO myregfile_HILO(
    	.clk    (clk    ),
        .LO_we  (HI_we   ),
        .HI_we  (LO_we   ),
        .LOwdata(HI_rf_data),
        .HIwdata(LO_rf_data),
        .HIrdata(HIdata    ),
        .LOrdata(LOdata    )
    );
    
   //assign HIdata=      ex_HI_rf_we?ex_HI_rf_data:HIdata_xxl;
   //assign LOdata=      ex_LO_rf_we?ex_LO_rf_data:LOdata_xxl;
   
    //store in HILO
    assign HI_we=inst_div|inst_divu|inst_mult|inst_multu|inst_mthi;
    assign LO_we=inst_div|inst_divu|inst_mult|inst_multu|inst_mtlo;
    
    assign ex_opcode = inst[31:26];
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;
    
    wire [3:0] data_b, data_h, data_w, data_ram_sel_ex;
    assign data_b = (ex_result[1:0] == 2'b00) ? 4'b0001 : 
                        (ex_result[1:0] == 2'b01) ? 4'b0010 :
                        (ex_result[1:0] == 2'b10) ? 4'b0100 : 4'b1000;
    assign data_h = (ex_result[1:0] == 2'b00) ? 4'b0011 : 4'b1100;
    assign data_w = 4'b1111;
    assign data_sram_en = data_ram_en;
    assign data_ram_sel_ex =  {4{data_ram_sel_id[0]}} & data_w 
                               |{4{data_ram_sel_id[1]}} & data_h
                               |{4{data_ram_sel_id[2]}} & data_b;
    assign data_sram_wen = data_ram_wen ? data_ram_sel_ex : 4'b0;
    assign data_sram_addr = ex_result;
    assign data_sram_wdata = ({32{data_ram_sel_id[0]}} & rf_rdata2) 
                             | ({32{data_ram_sel_id[1]}} & {2{rf_rdata2[15:0]}}) 
                             | ({32{data_ram_sel_id[2]}} & {4{rf_rdata2[7:0]}});






    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    assign ex_result =inst_mfhi? HIdata : 
                      inst_mflo? LOdata : alu_result;  

    // MUL part
    wire [63:0] mul_result;
    wire mul_signed; // 有符号乘法标记
    assign mul_signed = inst_mult;
    
    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),
        .mul_signed (mul_signed     ),
        .ina        (alu_src1       ), // 乘法源操作数1
        .inb        (alu_src2       ), // 乘法源操作数2
        .result     (mul_result     ) // 乘法结果 64bit
    );
    // DIV part
    wire [63:0] div_result;

    wire div_ready_i;
    reg stallreq_for_div;
    assign stallreq_for_ex = stallreq_for_div;

    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;
    
    
    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      )
    );

    
    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end
    

    assign HI_rf_data=inst_div|inst_divu ? div_result[63:32]:
                  inst_mult|inst_multu ? mul_result[63:32]:
                  inst_mthi ? alu_src1 : HIdata;
    assign LO_rf_data=inst_div|inst_divu ? div_result[31:0]:
                  inst_mult|inst_multu ? mul_result[31:0]:
                  inst_mtlo ? alu_src1 : LOdata;
                  
    assign ex_to_rf_bus = {    
        rf_we,
        rf_waddr,
        ex_result
    };

    assign ex_to_mem_bus = {
        data_ram_sel_id,
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_sel_ex,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };


    // mul_result 和 div_result 可以直接使用
    
    
endmodule