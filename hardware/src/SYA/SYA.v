//======================================================
// Copyright (C) 2020 By 
// All Rights Reserved
//======================================================
// Module : 
// Author : 
// Contact : 
// Date : 
//=======================================================
// Description :
//========================================================
module SYA #(
    parameter ACT_WIDTH  = 8,
    parameter WGT_WIDTH  = 8,
    parameter ACC_WIDTH  = ACT_WIDTH+WGT_WIDTH+10, //26
    parameter NUM_ROW    = 16,
    parameter NUM_COL    = 16,
    parameter NUM_BANK   = 4,
    parameter SRAM_WIDTH = 256,
    parameter QNT_WIDTH  = 8,
    parameter CHI_WIDTH  = 10,
    parameter IDX_WIDTH  = 16,
    parameter NUM_OUT    = NUM_BANK
  )(
    input                                     clk,
    input                                     rst_n,

    input                                     CCUSYA_Rst,
    
    input                                     CCUSYA_CfgVld,
    output                                    SYACCU_CfgRdy,
    
    input  [2                           -1:0] CCUSYA_CfgMod,
    input  [IDX_WIDTH                   -1:0] CCUSYA_CfgNip,
    input  [CHI_WIDTH                   -1:0] CCUSYA_CfgChi,
    
    input  [QNT_WIDTH                   -1:0] CCUSYA_CfgScale,
    input  [ACT_WIDTH                   -1:0] CCUSYA_CfgShift,
    input  [ACT_WIDTH                   -1:0] CCUSYA_CfgZp,
    
    input  [ACT_WIDTH*NUM_ROW*NUM_BANK  -1:0] GLBSYA_Act,
    input                                     GLBSYA_ActVld,
    output                                    SYAGLB_ActRdy,
    
    input  [WGT_WIDTH*NUM_COL*NUM_BANK  -1:0] GLBSYA_Wgt,
    input                                     GLBSYA_WgtVld,
    output                                    SYAGLB_WgtRdy,

    output [ACT_WIDTH*NUM_ROW*NUM_BANK  -1:0] SYAGLB_Ofm,
    output [NUM_OUT                     -1:0] SYAGLB_OfmVld,
    input  [NUM_OUT                     -1:0] GLBSYA_OfmRdy
  );
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam  FM_WIDTH = ACT_WIDTH;

wire cfg_vld = CCUSYA_CfgVld;
wire cfg_rdy = 'd1;

wire [2         -1:0] cfg_mod;
wire [IDX_WIDTH -1:0] cfg_nip;
wire [CHI_WIDTH -1:0] cfg_chi;
wire [CHI_WIDTH   :0] cfg_chi_cnt = cfg_chi + NUM_COL-1; //cfg_mod == 'd0 ? cfg_chi + NUM_COL*2 : ( cfg_mod == 'd1 ? cfg_chi + NUM_COL : cfg_chi + NUM_COL*4);

wire [QNT_WIDTH -1:0] quant_scale;
wire [ACT_WIDTH -1:0] quant_shift;
wire [ACT_WIDTH -1:0] quant_zerop;

wire act_en = GLBSYA_ActVld & SYAGLB_ActRdy;
wire wgt_en = GLBSYA_WgtVld & SYAGLB_WgtRdy;

wire bank_en = act_en && wgt_en;

wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH -1:0] bank_out_fm;

reg  [NUM_BANK -1:0][NUM_COL -1:0] bank_ena_you;
reg  [NUM_BANK -1:0][NUM_ROW -1:0] bank_ena_xia;
reg  [NUM_BANK -1:0] bank_din_vld;
wire [NUM_BANK -1:0] bank_din_rdy;
wire [NUM_BANK -1:0] bank_din_rdy_d;
reg  [NUM_BANK -1:0] bank_din_rdy_tmp;
wire [NUM_BANK -1:0] bank_din_ena = bank_din_vld & bank_din_rdy;
wire [NUM_BANK -1:0] bank_din_ena_d;
wire [NUM_BANK -1:0][NUM_ROW -1:0] bank_din_ena_s;
wire [NUM_BANK -1:0] bank_din_run;
wire [NUM_BANK -1:0] bank_din_don;
wire [NUM_BANK -1:0] bank_act_rdy;
wire [NUM_BANK -1:0] bank_wgt_rdy;
reg  [NUM_BANK -1:0] bank_act_rdy_tmp;
reg  [NUM_BANK -1:0] bank_wgt_rdy_tmp;

wire pe_idle = ~|{bank_ena_you, bank_ena_xia};

wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] bank_pkg_act = GLBSYA_Act;
wire [NUM_BANK -1:0][NUM_ROW -1:0][WGT_WIDTH  -1:0] bank_pkg_wgt = GLBSYA_Wgt;

reg  [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] bank_din_act;
wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] bank_out_act;

reg  [NUM_BANK -1:0][NUM_COL -1:0][WGT_WIDTH  -1:0] bank_din_wgt;
wire [NUM_BANK -1:0][NUM_COL -1:0][WGT_WIDTH  -1:0] bank_out_wgt;

wire [NUM_BANK -1:0] bank_you_rst;
wire [NUM_BANK -1:0] bank_xia_rst;
reg  [NUM_BANK -1:0] bank_din_rst;
reg  [NUM_BANK -1:0] [CHI_WIDTH  :0] bank_acc_cnt;
reg  bank_acc_rdy;
wire [NUM_BANK -1:0] bank_acc_run;
wire [NUM_BANK -1:0] bank_acc_out;
reg  [NUM_BANK -1:0][NUM_ROW -1:0] bank_out_ena;
reg  [NUM_BANK -1:0][NUM_ROW -1:0] bank_row_out_ena;

wire [NUM_BANK -1:0][NUM_ROW -1:0][ACT_WIDTH  -1:0] sync_din = bank_out_fm;
wire [NUM_BANK -1:0][NUM_ROW -1:0] sync_din_vld = bank_row_out_ena & bank_out_ena & bank_din_ena_s;
wire [NUM_BANK -1:0][NUM_ROW -1:0] sync_din_rdy;

wire [NUM_OUT*SRAM_WIDTH/2           -1:0]  sync_out;
wire [NUM_OUT                        -1:0]  sync_out_vld;
wire [NUM_OUT                        -1:0]  sync_out_rdy = GLBSYA_OfmRdy;

wire cfg_en = cfg_vld && cfg_rdy;

wire rst_reset = CCUSYA_Rst;

CPM_REG_E #( 2         ) CFG_MODE_REG0 ( clk, rst_n, cfg_en, CCUSYA_CfgMod, cfg_mod);
CPM_REG_E #( IDX_WIDTH ) CFG_MODE_REG1 ( clk, rst_n, cfg_en, CCUSYA_CfgNip, cfg_nip);
CPM_REG_E #( CHI_WIDTH ) CFG_MODE_REG2 ( clk, rst_n, cfg_en, CCUSYA_CfgChi, cfg_chi);

CPM_REG_E #( QNT_WIDTH ) CFG_MODE_REG3 ( clk, rst_n, cfg_en, CCUSYA_CfgScale, quant_scale);
CPM_REG_E #( ACT_WIDTH ) CFG_MODE_REG4 ( clk, rst_n, cfg_en, CCUSYA_CfgShift, quant_shift);
CPM_REG_E #( ACT_WIDTH ) CFG_MODE_REG5 ( clk, rst_n, cfg_en, CCUSYA_CfgZp   , quant_zerop);

CPM_REG #( NUM_BANK ) BANK_BIN_RDY_REG5 ( clk, rst_n, bank_din_rdy, bank_din_rdy_d);

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
genvar gen_i;
generate
  for( gen_i=0 ; gen_i < NUM_BANK; gen_i = gen_i+1 ) begin : BANK_BLOCK
  
    always @ ( posedge clk or negedge rst_n )begin
      if( ~rst_n )
        bank_ena_you[gen_i] <= 'd0;
      else if( bank_din_rdy[gen_i] )
        bank_ena_you[gen_i] <= {bank_ena_you[gen_i][NUM_COL-2:0], bank_din_vld[gen_i]};
    end

    always @ ( posedge clk or negedge rst_n )begin
      if( ~rst_n )
        bank_ena_xia[gen_i] <= 'd0;
      else if( bank_din_rdy[gen_i] )
        bank_ena_xia[gen_i] <= {bank_ena_xia[gen_i][NUM_ROW-2:0], bank_din_vld[gen_i]};
    end

    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      bank_acc_cnt[gen_i] <= 'd0;
    else if( CCUSYA_Rst )
      bank_acc_cnt[gen_i] <= 'd0;
    else if( bank_din_vld[gen_i] && bank_din_rdy[gen_i] )
      bank_acc_cnt[gen_i] <= bank_acc_cnt[gen_i] + 'd1;
    end
  
    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      bank_out_ena[gen_i] <= 'd0;
    else if( CCUSYA_Rst )
      bank_out_ena[gen_i] <= 'd0;
    else if( (bank_acc_cnt[gen_i] == cfg_chi && |cfg_chi) && (bank_din_vld[gen_i] && bank_din_rdy[gen_i]) )
      bank_out_ena[gen_i] <= {NUM_ROW{1'd1}};
    end
    
    always @ ( posedge clk or negedge rst_n )begin
    if( ~rst_n )
      bank_row_out_ena[gen_i] <= 'd0;
    else if( CCUSYA_Rst )
      bank_row_out_ena[gen_i] <= 'd0;
    else if( bank_din_rdy[gen_i] )
      bank_row_out_ena[gen_i] <= bank_row_out_ena[gen_i][NUM_ROW -1] ? {bank_row_out_ena[gen_i][NUM_ROW -2:0], bank_acc_out[gen_i]} & bank_row_out_ena[gen_i] : 
                                                                       {bank_row_out_ena[gen_i][NUM_ROW -2:0], bank_acc_out[gen_i]} | bank_row_out_ena[gen_i];
    end
    
    assign bank_din_ena_s[gen_i] = {NUM_ROW{bank_din_rdy_d[gen_i]}};
    
    assign bank_acc_run[gen_i] = 1'b1; // bank_acc_cnt[gen_i] <= cfg_chi_cnt && bank_acc_rdy;
    assign bank_acc_out[gen_i] = bank_acc_cnt[gen_i] % cfg_chi == 0;
    
    assign bank_din_run[gen_i] = bank_acc_cnt[gen_i] <= cfg_chi_cnt;
    assign bank_din_don[gen_i] = 1'b0; //bank_acc_cnt[gen_i] >  cfg_chi_cnt;    
    
    assign bank_din_rdy[gen_i] = bank_acc_rdy && &sync_din_rdy[gen_i] && bank_din_rdy_tmp[gen_i];
    assign bank_act_rdy[gen_i] = bank_acc_rdy && &sync_din_rdy[gen_i] && bank_act_rdy_tmp[gen_i];
    assign bank_wgt_rdy[gen_i] = bank_acc_rdy && &sync_din_rdy[gen_i] && bank_wgt_rdy_tmp[gen_i];
end
endgenerate

always @ ( posedge clk or negedge rst_n )begin
if( ~rst_n )
  bank_acc_rdy <= 'd0;
else if( CCUSYA_Rst )
  bank_acc_rdy <= 'd0;
else if( cfg_en )
  bank_acc_rdy <= 'd1;
end

always @ (*)
begin
  bank_act_rdy_tmp[1] = bank_act_rdy_tmp[0];
  bank_act_rdy_tmp[2] = bank_act_rdy_tmp[0];
  bank_act_rdy_tmp[3] = bank_act_rdy_tmp[0];
end

always @ (*)
begin
  
  bank_wgt_rdy_tmp[1] = bank_wgt_rdy_tmp[0];
  bank_wgt_rdy_tmp[2] = bank_wgt_rdy_tmp[0];
  bank_wgt_rdy_tmp[3] = bank_wgt_rdy_tmp[0];
end

always @ (*)
begin
  bank_act_rdy_tmp[0] = bank_din_don[0] ? 'd1 : GLBSYA_WgtVld;
  bank_wgt_rdy_tmp[0] = bank_din_don[0] ? 'd1 : GLBSYA_ActVld;
end

always @ (*)
begin
  if( cfg_mod == 'd0 )
    bank_din_rdy_tmp[0] = bank_din_don[0] ? bank_din_rdy_tmp[1] && bank_din_rdy_tmp[2] : GLBSYA_ActVld && GLBSYA_WgtVld;
  else
    bank_din_rdy_tmp[0] = bank_din_don[0] ? bank_din_rdy_tmp[1] : GLBSYA_ActVld && GLBSYA_WgtVld;
end

always @ (*)
begin
  if( cfg_mod == 'd0 )
    bank_din_rdy_tmp[1] = bank_din_don[1] ? bank_din_rdy_tmp[3] : GLBSYA_ActVld && GLBSYA_WgtVld;
  else if( cfg_mod == 'd1 )
    bank_din_rdy_tmp[1] = bank_din_don[0] ? (bank_din_don[1] ? bank_din_rdy_tmp[2] : GLBSYA_WgtVld) : GLBSYA_ActVld && GLBSYA_WgtVld;
  else
    bank_din_rdy_tmp[1] = bank_din_don[0] ? (bank_din_don[1] ? bank_din_rdy_tmp[2] : GLBSYA_ActVld) : GLBSYA_ActVld && GLBSYA_WgtVld;
end

always @ (*)
begin
  if( cfg_mod == 'd0 )
    bank_din_rdy_tmp[2] = bank_din_don[2] ? bank_din_rdy_tmp[3] : GLBSYA_ActVld && GLBSYA_WgtVld;
  else if( cfg_mod == 'd1 )
    bank_din_rdy_tmp[2] = bank_din_don[0] ? (bank_din_don[2] ? bank_din_rdy_tmp[3] : GLBSYA_WgtVld) : GLBSYA_ActVld && GLBSYA_WgtVld;
  else
    bank_din_rdy_tmp[2] = bank_din_don[0] ? (bank_din_don[2] ? bank_din_rdy_tmp[3] : GLBSYA_ActVld) : GLBSYA_ActVld && GLBSYA_WgtVld;
end

always @ (*)
begin
  if( cfg_mod == 'd0 )
    bank_din_rdy_tmp[3] = bank_din_don[1] || (GLBSYA_ActVld && GLBSYA_WgtVld);
  else if( cfg_mod == 'd1 )
    bank_din_rdy_tmp[3] = bank_din_don[0] ? (bank_din_don[3] ? 'd1 : GLBSYA_WgtVld) : GLBSYA_ActVld && GLBSYA_WgtVld;
  else
    bank_din_rdy_tmp[3] = bank_din_don[0] ? (bank_din_don[3] ? 'd1 : GLBSYA_ActVld) : GLBSYA_ActVld && GLBSYA_WgtVld;
end

always @ (*)
begin
    bank_din_act[0] = bank_pkg_act[0];
    bank_din_wgt[0] = GLBSYA_Wgt;
    bank_din_rst[0] = bank_out_ena[0][NUM_ROW-1];
    bank_din_vld[0] = GLBSYA_ActVld && GLBSYA_WgtVld && bank_acc_run[0];
    
    bank_din_act[1] = cfg_mod == 'd2 ? bank_pkg_act[1] : bank_out_act[0];
    bank_din_wgt[1] = cfg_mod == 'd2 ? bank_out_wgt[0] : bank_pkg_wgt[1];
    bank_din_rst[1] = cfg_mod == 'd2 ? bank_xia_rst[0] : bank_you_rst[0];
    bank_din_vld[1] =(cfg_mod == 'd2 ? bank_ena_xia[0][NUM_COL -1] && GLBSYA_ActVld: bank_ena_you[0][NUM_COL -1] && GLBSYA_WgtVld ) && bank_acc_run[1];
    
end

always @ (*)
begin
    bank_din_act[2] = cfg_mod == 'd1 ? bank_out_act[1] : bank_pkg_act[2];
    bank_din_wgt[2] = cfg_mod == 'd0 ? bank_out_wgt[0] : cfg_mod == 'd1 ? bank_pkg_wgt[2] : bank_out_wgt[1];
    bank_din_rst[2] = cfg_mod == 'd0 ? bank_xia_rst[0] : cfg_mod == 'd1 ? bank_you_rst[1] : bank_xia_rst[1];
    bank_din_vld[2] =(cfg_mod == 'd0 ? bank_ena_xia[0][NUM_COL -1] && GLBSYA_ActVld: cfg_mod == 'd1 ? bank_ena_you[1][NUM_COL -1] && GLBSYA_WgtVld : bank_ena_xia[1][NUM_COL -1] && GLBSYA_ActVld ) && bank_acc_run[2];

    bank_din_act[3] = cfg_mod == 'd2 ? bank_pkg_act[3] : bank_out_act[2];
    bank_din_wgt[3] = cfg_mod == 'd0 ? bank_out_wgt[1] : cfg_mod == 'd1 ? bank_pkg_wgt[3] : bank_out_wgt[2];
    bank_din_rst[3] = cfg_mod == 'd0 ? bank_xia_rst[1] : cfg_mod == 'd1 ? bank_you_rst[2] : bank_xia_rst[2];
    bank_din_vld[3] =(cfg_mod == 'd0 ? bank_ena_xia[1][NUM_COL -1] && (bank_din_don[1] ? bank_din_rdy_tmp[3] : GLBSYA_ActVld && GLBSYA_WgtVld) : 
                      cfg_mod == 'd1 ? bank_ena_you[2][NUM_COL -1] && GLBSYA_WgtVld: bank_ena_xia[2][NUM_COL -1] && GLBSYA_ActVld ) && bank_acc_run[3];
end

//=====================================================================================================================
// Logic Design :
//=====================================================================================================================

    PE_BANK #(
      .NUM_ROW             ( NUM_ROW            ),
      .NUM_COL             ( NUM_COL            ),
      .QNT_WIDTH           ( QNT_WIDTH          ),
      .ACT_WIDTH           ( ACT_WIDTH          ),
      .WGT_WIDTH           ( WGT_WIDTH          ),
      .PSUM_WIDTH          ( ACC_WIDTH          ),
      .FM_WIDTH            ( ACT_WIDTH          )
    ) PE_BANK_U_I [NUM_BANK -1:0] (               

      .clk                 ( clk                ),
      .rst_n               ( rst_n              ),
      
      .rst_reset           ( rst_reset          ),
                           
      .quant_scale         ( quant_scale        ),
      .quant_shift         ( quant_shift        ),
      .quant_zero_point    ( quant_zerop        ),
                           
      .in_vld_left         ( bank_din_vld       ),
      .in_rdy_left         ( bank_din_rdy       ),
      
      .out_fm              ( bank_out_fm        ),
                           
      .in_act_left         ( bank_din_act       ),
      .out_act_right       ( bank_out_act       ),
                           
      .in_wgt_above        ( bank_din_wgt       ),
      .out_wgt_below       ( bank_out_wgt       ),
                           
      .in_acc_reset_left   ( bank_din_rst       ),
      .out_acc_reset_right ( bank_you_rst       ),
      .out_acc_reset_below ( bank_xia_rst       )
    );

    SYNC_SHAPE #(
      .ACT_WIDTH           ( ACT_WIDTH          ),
      .SRAM_WIDTH          ( SRAM_WIDTH         ),
      .NUM_BANK            ( NUM_BANK           ),
      .NUM_ROW             ( NUM_ROW            ),
      .NUM_OUT             ( NUM_OUT            )
    ) SYNC_SHAPE_U (               

      .clk                 ( clk                ),
      .rst_n               ( rst_n              ),
                           
      .din_data            ( sync_din           ),
      .din_data_vld        ( sync_din_vld       ),
      .din_data_rdy        ( sync_din_rdy       ),
                           
      .out_data            ( sync_out           ),
      .out_data_vld        ( sync_out_vld       ),
      .out_data_rdy        ( sync_out_rdy       )
    );

assign SYACCU_CfgRdy = cfg_rdy && pe_idle;
assign SYAGLB_ActRdy = &bank_din_rdy;
assign SYAGLB_WgtRdy = &bank_din_rdy;
assign SYAGLB_OfmVld = sync_out_vld;
assign SYAGLB_Ofm = sync_out;

endmodule