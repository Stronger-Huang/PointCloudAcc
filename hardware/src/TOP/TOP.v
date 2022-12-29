// This is a simple example.
// You can make a your own header file and set its path to settings.
// (Preferences > Package Settings > Verilog Gadget > Settings - User)
//
//      "header": "Packages/Verilog Gadget/template/verilog_header.v"
//
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : CCU.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
module TOP #(
    parameter CLOCK_PERIOD   = 10,

    parameter PORT_WIDTH     = 128,
    parameter SRAM_WIDTH     = 256,
    parameter SRAM_BYTE_WIDTH= 8,
    parameter SRAM_WORD      = 128,
    parameter ADDR_WIDTH     = 16,
    parameter DRAM_ADDR_WIDTH= 32,  
    parameter ISA_SRAM_WORD  = 64,
    parameter ITF_NUM_RDPORT = 2,  
    parameter ITF_NUM_WRPORT = 5, // + CCU
    parameter GLB_NUM_RDPORT = 15,  // 10 + 5(POOL_CORE)
    parameter GLB_NUM_WRPORT = 9, 
    parameter MAXPAR         = 32,
    parameter NUM_BANK       = 32,
    parameter POOL_CORE      = 6,
    parameter POOL_COMP_CORE = 64, 

    // NetWork Parameters
    parameter IDX_WIDTH      = 16,
    parameter CHN_WIDTH      = 12,
    parameter ACT_WIDTH      = 8,
    parameter MAP_WIDTH      = 6,

    parameter CRD_WIDTH      = 16,   
    parameter CRD_DIM        = 3,   
    parameter NUM_SORT_CORE  = 8,

    parameter SYA_NUM_ROW    = 16,
    parameter SYA_NUM_COL    = 16,
    parameter SYA_NUM_BANK   = 4,
    parameter QNTSL_WIDTH    = 20,
    parameter MASK_ADDR_WIDTH = $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH)

    )(
    input                           I_SysRst_n    , 
    input                           I_SysClk      , 
    input                           I_StartPulse  ,
    input                           I_BypAsysnFIFO, 
    inout   [PORT_WIDTH     -1 : 0] IO_Dat        , 
    inout                           IO_DatVld     , 
    inout                           IO_DatLast    , 
    inout                           OI_DatRdy     , 
    output                          O_DatOE       ,
    output                          O_NetFnh  

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam GLBWRIDX_ITFACT = 0;
localparam GLBWRIDX_ITFWGT = 1;
localparam GLBWRIDX_ITFCRD = 2;
localparam GLBWRIDX_ITFMAP = 3;
localparam GLBWRIDX_SYAOFM = 4;
localparam GLBWRIDX_POLOFM = 5;
localparam GLBWRIDX_CTRDST = 6;
localparam GLBWRIDX_CTRMAP = 7;
localparam GLBWRIDX_CTRFMK = 8; // FPS Writes Mask

localparam GLBRDIDX_ITFMAP = 0;
localparam GLBRDIDX_ITFOFM = 1;
localparam GLBRDIDX_SYAACT = 2;
localparam GLBRDIDX_SYAWGT = 3;
localparam GLBRDIDX_CTRCRD = 4;
localparam GLBRDIDX_CTRDST = 5;
localparam GLBRDIDX_CTRFMK = 6; // FPS Read MASK
localparam GLBRDIDX_CTRKMK = 7; // KNN Read MASK
localparam GLBRDIDX_POLMAP = 8;
localparam GLBRDIDX_POLOFM = 9;


localparam DISTSQR_WIDTH     =  $clog2( CRD_WIDTH*2*$clog2(CRD_DIM) );
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// System
wire                            clk;
wire                            rst_n;
wire                            StartPulse_Deb;
wire                            StartPulse_Deb_d;
// ITF
wire [PORT_WIDTH        -1 : 0] ITFPAD_Dat;
wire [PORT_WIDTH        -1 : 0] PADITF_Dat;

wire                            ITFPAD_DatOE;
wire                            ITFPAD_DatVld;
wire                            ITFPAD_DatLast;
wire                            PADITF_DatRdy;

wire                            PADITF_DatVld;
wire                            PADITF_DatLast;
wire                            ITFPAD_DatRdy;

// TOP-ITF
wire [1*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)           -1 : 0] TOPITF_EmptyFull;
wire [ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)  -1 : 0] TOPITF_ReqNum;  
wire [ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT)  -1 : 0] TOPITF_Addr;    

wire [SRAM_WIDTH*ITF_NUM_RDPORT               -1 : 0] TOPITF_Dat;    
wire [ITF_NUM_RDPORT                          -1 : 0] TOPITF_DatVld;
wire [ITF_NUM_RDPORT                          -1 : 0] TOPITF_DatLast; 
wire [ITF_NUM_RDPORT                          -1 : 0] ITFTOP_DatRdy; 

wire [SRAM_WIDTH*ITF_NUM_WRPORT               -1 : 0] ITFTOP_Dat;    
wire [ITF_NUM_WRPORT                          -1 : 0] ITFTOP_DatVld; 
wire [ITF_NUM_WRPORT                          -1 : 0] ITFTOP_DatLast; 
wire [ITF_NUM_WRPORT                          -1 : 0] TOPITF_DatRdy;


// CCU
wire                                              TOPCCU_start;
wire                                              CCUITF_Empty ;
wire [ADDR_WIDTH                          -1 : 0] CCUITF_ReqNum;
wire [ADDR_WIDTH                          -1 : 0] CCUITF_Addr  ;
wire  [SRAM_WIDTH                         -1 : 0] ITFCCU_Dat;          
wire                                              ITFCCU_DatVld;          
wire                                              CCUITF_DatRdy;
wire  [DRAM_ADDR_WIDTH*(ITF_NUM_RDPORT+ITF_NUM_WRPORT) -1 : 0] CCUITF_BaseAddr;
wire                                              CCUSYA_Rst;  //
wire                                              CCUSYA_CfgVld;
wire                                              SYACCU_CfgRdy;
wire  [2                                  -1 : 0] CCUSYA_CfgMod;
wire  [IDX_WIDTH                          -1 : 0] CCUSYA_CfgNip; 
wire  [CHN_WIDTH                          -1 : 0] CCUSYA_CfgChi;         
wire  [QNTSL_WIDTH                        -1 : 0] CCUSYA_CfgScale;        
wire  [ACT_WIDTH                          -1 : 0] CCUSYA_CfgShift;        
wire  [ACT_WIDTH                          -1 : 0] CCUSYA_CfgZp;
wire                                              CCUPOL_Rst;
wire                                              CCUPOL_CfgVld;
wire                                              POLCCU_CfgRdy;
wire  [MAP_WIDTH                          -1 : 0] CCUPOL_CfgK;
wire  [IDX_WIDTH                          -1 : 0] CCUPOL_CfgNip;
wire  [CHN_WIDTH                          -1 : 0] CCUPOL_CfgChi;
wire  [IDX_WIDTH*POOL_CORE                -1 : 0] CCUPOL_AddrMin;
wire  [IDX_WIDTH*POOL_CORE                -1 : 0] CCUPOL_AddrMax;
wire                                              CCUCTR_Rst;
wire                                              CCUCTR_CfgVld;
wire                                              CTRCCU_CfgRdy;
wire                                              CCUCTR_CfgMod;        
wire  [IDX_WIDTH                          -1 : 0] CCUCTR_CfgNip;                   
wire  [IDX_WIDTH                          -1 : 0] CCUCTR_CfgNop;         
wire  [MAP_WIDTH                          -1 : 0] CCUCTR_CfgK;  
wire                                              CCUGLB_Rst;
wire [GLB_NUM_RDPORT + GLB_NUM_WRPORT     -1 : 0] CCUGLB_CfgVld;         
wire [GLB_NUM_RDPORT + GLB_NUM_WRPORT     -1 : 0] GLBCCU_CfgRdy;         
wire [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)* NUM_BANK -1 : 0] CCUGLB_CfgPortBankFlag;
wire [ADDR_WIDTH*(GLB_NUM_RDPORT+GLB_NUM_WRPORT)  -1 : 0] CCUGLB_CfgPortNum; 
wire [($clog2(MAXPAR) + 1)*(GLB_NUM_RDPORT+GLB_NUM_WRPORT)-1 : 0] CCUGLB_CfgPortParBank;


// GLB
wire [SRAM_WIDTH*MAXPAR*GLB_NUM_WRPORT   -1: 0] WrPortDat;
wire [GLB_NUM_WRPORT                     -1: 0] WrPortDatVld;
wire [GLB_NUM_WRPORT                     -1: 0] WrPortDatLast;
wire [GLB_NUM_WRPORT                     -1: 0] WrPortDatRdy;
wire [GLB_NUM_WRPORT                     -1: 0] WrPortEmpty;
wire [ADDR_WIDTH*GLB_NUM_WRPORT          -1: 0] WrPortReqNum;
wire [ADDR_WIDTH*GLB_NUM_WRPORT          -1: 0] WrPortAddr_Out; // Detect
wire [GLB_NUM_WRPORT                     -1: 0] WrPortAddrUse; //  Mode1: Use Address
wire [ADDR_WIDTH*GLB_NUM_WRPORT          -1: 0] WrPortAddr;
wire [SRAM_WIDTH*MAXPAR*GLB_NUM_RDPORT   -1: 0] RdPortDat;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortDatVld;
// wire [GLB_NUM_RDPORT                     -1: 0] RdPortDatLast;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortDatRdy;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortFull;
wire [ADDR_WIDTH*GLB_NUM_RDPORT          -1: 0] RdPortReqNum;
wire [ADDR_WIDTH*GLB_NUM_RDPORT          -1: 0] RdPortAddr_Out;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortAddrUse;
wire [ADDR_WIDTH*GLB_NUM_RDPORT          -1: 0] RdPortAddr;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortAddrVld;
wire [GLB_NUM_RDPORT                     -1: 0] RdPortAddrRdy;  

// CTR
wire [IDX_WIDTH           -1 : 0] CTRGLB_CrdAddr;   
wire                              CTRGLB_CrdAddrVld; 
wire                              GLBCTR_CrdAddrRdy;
wire [SRAM_WIDTH          -1 : 0 ]GLBCTR_Crd;        
wire                              GLBCTR_CrdVld;     
wire                              CTRGLB_CrdRdy;
wire [IDX_WIDTH           -1 : 0] CTRGLB_DistRdAddr; 
wire                              CTRGLB_DistRdAddrVld;
wire                              GLBCTR_DistRdAddrRdy;
wire [SRAM_WIDTH          -1 : 0] GLBCTR_DistIdx;    
wire                              GLBCTR_DistIdxVld;    
wire                              CTRGLB_DistIdxRdy;    
wire [IDX_WIDTH           -1 : 0] CTRGLB_DistWrAddr;
wire [SRAM_WIDTH          -1 : 0] CTRGLB_DistIdx;   
wire                              CTRGLB_DistIdxVld;
wire                              GLBCTR_DistIdxRdy;
wire [SRAM_WIDTH          -1 : 0 ]CTRGLB_Map;   
wire                              CTRGLB_MapVld;     
wire                              GLBCTR_MapRdy; 

wire [MASK_ADDR_WIDTH    -1 : 0] KNNGLB_MaskRdAddr;
wire                             KNNGLB_MaskRdAddrVld;
wire                             GLBKNN_MaskRdAddrRdy;
wire [SRAM_WIDTH         -1 : 0] GLBKNN_MaskRdDat;
wire                             GLBKNN_MaskRdDatVld;
wire                             KNNGLB_MaskRdDatRdy;
    // Input Mask Bit
wire [MASK_ADDR_WIDTH    -1 : 0] FPSGLB_MaskRdAddr;
wire                             FPSGLB_MaskRdAddrVld;
wire                             GLBFPS_MaskRdAddrRdy;
wire [SRAM_WIDTH         -1 : 0] GLBFPS_MaskRdDat;
wire                             GLBFPS_MaskRdDatVld; // Not Used
wire                             FPSGLB_MaskRdDatRdy;  

    // Output Mask Bit
wire [MASK_ADDR_WIDTH     -1 : 0] FPSGLB_MaskWrAddr;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrBitEn;
wire                              FPSGLB_MaskWrDatVld;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrDat;
wire                              GLBFPS_MaskWrDatRdy;  // Not Used

// SYA
wire [SRAM_BYTE_WIDTH*SYA_NUM_ROW*SYA_NUM_COL*SYA_NUM_BANK/16   -1 : 0] SYAGLB_Ofm;
wire [SYA_NUM_BANK                                              -1 : 0] SYAGLB_OfmVld;
wire [SYA_NUM_BANK                                              -1 : 0] GLBSYA_OfmRdy;
wire [SRAM_BYTE_WIDTH*SYA_NUM_ROW*SYA_NUM_BANK                  -1 : 0] GLBSYA_Act;
wire                                                                    GLBSYA_ActVld;
wire                                                                    SYAGLB_ActRdy ;
wire [SRAM_BYTE_WIDTH*SYA_NUM_COL*SYA_NUM_BANK                  -1 : 0] GLBSYA_Wgt;
wire                                                                    GLBSYA_WgtVld;
wire                                                                    SYAGLB_WgtRdy ;

// POOL
wire                                                    GLBPOL_MapVld ;
wire [SRAM_WIDTH                                -1 : 0] GLBPOL_Map    ;
wire                                                    POLGLB_MapRdy ;
wire [POOL_CORE                                 -1 : 0] POLGLB_AddrVld;
wire [ADDR_WIDTH*POOL_CORE                      -1 : 0] POLGLB_Addr   ;
wire [POOL_CORE                                 -1 : 0] GLBPOL_AddrRdy;
wire [SRAM_BYTE_WIDTH*POOL_COMP_CORE*POOL_CORE  -1 : 0] GLBPOL_Ofm     ;
wire [POOL_CORE                                 -1 : 0] GLBPOL_OfmVld  ;
wire [POOL_CORE                                 -1 : 0] POLGLB_OfmRdy  ;
wire [SRAM_BYTE_WIDTH*POOL_COMP_CORE            -1 : 0] POLGLB_Ofm     ;
wire                                                    POLGLB_OfmVld  ;
wire                                                    GLBPOL_OfmRdy  ;

//=====================================================================================================================
// Logic Design: Debounce
//=====================================================================================================================
DEB #(
    .FREQ  ( 50    )
)u_DEB(
    .CLK   ( clk            ),
    .RST_N ( rst_n          ),
    .BTN   ( I_StartPulse   ),
    .SIGNAL( StartPulse_Deb )
);

assign TOPCCU_start = !StartPulse_Deb & StartPulse_Deb_d; // negedge

//=====================================================================================================================
// Logic Design
//=====================================================================================================================
assign {IO_Dat, IO_DatVld, IO_DatLast} = O_DatOE? {ITFPAD_Dat, ITFPAD_DatVld, ITFPAD_DatLast} : { {PORT_WIDTH{1'bz}}, 1'bz, 1'bz};
assign PADITF_DatRdy = OI_DatRdy;

assign {PADITF_Dat, PADITF_DatVld, PADITF_DatLast} = {IO_Dat, IO_DatVld, IO_DatLast};
assign OI_DatRdy = O_DatOE? 1'bz : ITFPAD_DatRdy;

assign clk  = I_SysClk;
assign rst_n= I_SysRst_n;


//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================

ITF#(
    .PORT_WIDTH       ( PORT_WIDTH      ),
    .SRAM_WIDTH       ( SRAM_WIDTH      ),
    .ADDR_WIDTH       ( ADDR_WIDTH      ),
    .DRAM_ADDR_WIDTH  ( DRAM_ADDR_WIDTH ),
    .ITF_NUM_RDPORT   ( ITF_NUM_RDPORT  ),
    .ITF_NUM_WRPORT   ( ITF_NUM_WRPORT  )
)u_ITF(
    .clk              ( clk              ),
    .rst_n            ( rst_n            ),
    .ITFPAD_DatOE     ( ITFPAD_DatOE     ),
    .ITFPAD_Dat       ( ITFPAD_Dat       ),
    .ITFPAD_DatVld    ( ITFPAD_DatVld    ),
    .ITFPAD_DatLast   ( ITFPAD_DatLast   ),
    .PADITF_DatRdy    ( PADITF_DatRdy    ),
    .PADITF_Dat       ( PADITF_Dat       ),
    .PADITF_DatVld    ( PADITF_DatVld    ),
    .PADITF_DatLast   ( PADITF_DatLast   ),
    .ITFPAD_DatRdy    ( ITFPAD_DatRdy    ),
    .TOPITF_EmptyFull ( TOPITF_EmptyFull ),
    .TOPITF_ReqNum    ( TOPITF_ReqNum    ),
    .TOPITF_Addr      ( TOPITF_Addr      ),
    .CCUITF_BaseAddr  ( CCUITF_BaseAddr  ),
    .TOPITF_Dat       ( TOPITF_Dat       ),
    .TOPITF_DatVld    ( TOPITF_DatVld    ),
    // .TOPITF_DatLast    ( TOPITF_DatLast   ),
    .ITFTOP_DatRdy    ( ITFTOP_DatRdy    ),
    .ITFTOP_Dat       ( ITFTOP_Dat       ),
    .ITFTOP_DatVld    ( ITFTOP_DatVld    ),
    .ITFTOP_DatLast   ( ITFTOP_DatLast   ),
    .TOPITF_DatRdy    ( TOPITF_DatRdy    )
);

assign TOPITF_EmptyFull = {RdPortFull[0 +: 2], WrPortEmpty[0 +: 4], CCUITF_Empty};
assign TOPITF_ReqNum    = {RdPortReqNum[ADDR_WIDTH*0 +: ADDR_WIDTH*2]*SRAM_WIDTH/PORT_WIDTH, WrPortReqNum[0 +: ADDR_WIDTH*4]*SRAM_WIDTH/PORT_WIDTH, CCUITF_ReqNum};
assign TOPITF_Addr      = {RdPortAddr_Out[ADDR_WIDTH*0 +: ADDR_WIDTH*2], WrPortAddr_Out[0 +: ADDR_WIDTH*4], CCUITF_Addr};

// First 2 port (GLBRDIDX_ITFMAP, GLBRDIDX_ITFOFM) directly connected to ITF and arbed inside ITF
assign TOPITF_Dat       = RdPortDat[SRAM_WIDTH*0 +: SRAM_WIDTH*2]; 
assign TOPITF_DatVld    = RdPortDatVld[0 +: 2];
// assign TOPITF_DatLast   = RdPortDatLast[0 +: 2];
assign RdPortDatRdy[0 +: 2] = ITFTOP_DatRdy;

assign RdPortAddrUse[GLBRDIDX_ITFMAP] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_ITFMAP] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_ITFMAP +: ADDR_WIDTH] = 0;
assign RdPortAddrUse[GLBRDIDX_ITFOFM] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_ITFOFM] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_ITFOFM +: ADDR_WIDTH] = 0;


assign WrPortAddrUse[0 +: 4] = {4{1'b0}};
assign WrPortAddr[ADDR_WIDTH*0 +: ADDR_WIDTH*4] = 'd0;
assign {WrPortDat[ (SRAM_WIDTH*MAXPAR)*0 +:  (SRAM_WIDTH*MAXPAR)*4], ITFCCU_Dat}= ITFTOP_Dat;
assign {WrPortDatVld[0 +: 4], ITFCCU_DatVld}                = ITFTOP_DatVld;
assign {WrPortDatLast[0 +: 4], ITFCCU_DatLast}              = ITFTOP_DatLast;
assign TOPITF_DatRdy                                        = {WrPortDatRdy[0 +: 4], CCUITF_DatRdy};

assign O_DatOE = ITFPAD_DatOE;

CCU#(
    .ISA_SRAM_WORD           ( ISA_SRAM_WORD    ),
    .SRAM_WIDTH              ( SRAM_WIDTH       ),
    .PORT_WIDTH              ( PORT_WIDTH       ),
    .POOL_CORE               ( POOL_CORE        ),
    .ADDR_WIDTH              ( ADDR_WIDTH       ),
    .DRAM_ADDR_WIDTH         ( DRAM_ADDR_WIDTH  ),
    .GLB_NUM_RDPORT          ( GLB_NUM_RDPORT   ),
    .GLB_NUM_WRPORT          ( GLB_NUM_WRPORT   ),
    .IDX_WIDTH               ( IDX_WIDTH        ),
    .CHN_WIDTH               ( CHN_WIDTH        ),
    .QNTSL_WIDTH             ( QNTSL_WIDTH        ),
    .ACT_WIDTH               ( ACT_WIDTH        ),
    .MAP_WIDTH               ( MAP_WIDTH        ),
    .MAXPAR                  ( MAXPAR           ),
    .NUM_BANK                ( NUM_BANK         ),
    .ITF_NUM_RDPORT          ( ITF_NUM_RDPORT   ),
    .ITF_NUM_WRPORT          ( ITF_NUM_WRPORT   )
)u_CCU(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .TOPCCU_start            ( TOPCCU_start            ),
    .CCUTOP_NetFnh           ( O_NetFnh                ),
    .CCUITF_Empty            ( CCUITF_Empty            ),
    .CCUITF_ReqNum           ( CCUITF_ReqNum           ),
    .CCUITF_Addr             ( CCUITF_Addr             ),
    .ITFCCU_Dat              ( ITFCCU_Dat              ),
    .ITFCCU_DatVld           ( ITFCCU_DatVld           ),
    .CCUITF_DatRdy           ( CCUITF_DatRdy           ),
    .CCUITF_BaseAddr         ( CCUITF_BaseAddr         ),
    .CCUSYA_Rst              ( CCUSYA_Rst              ),
    .CCUSYA_CfgVld           ( CCUSYA_CfgVld           ),
    .SYACCU_CfgRdy           ( SYACCU_CfgRdy           ),
    .CCUSYA_CfgMod           ( CCUSYA_CfgMod           ),
    .CCUSYA_CfgNip           ( CCUSYA_CfgNip           ),
    .CCUSYA_CfgChi           ( CCUSYA_CfgChi           ),
    .CCUSYA_CfgScale         ( CCUSYA_CfgScale         ),
    .CCUSYA_CfgShift         ( CCUSYA_CfgShift         ),
    .CCUSYA_CfgZp            ( CCUSYA_CfgZp            ),
    .CCUPOL_Rst              ( CCUPOL_Rst              ),
    .CCUPOL_CfgVld           ( CCUPOL_CfgVld           ),
    .POLCCU_CfgRdy           ( POLCCU_CfgRdy           ),
    .CCUPOL_CfgK             ( CCUPOL_CfgK             ),
    .CCUPOL_CfgNip           ( CCUPOL_CfgNip           ),
    .CCUPOL_CfgChi           ( CCUPOL_CfgChi           ),
    .CCUPOL_AddrMin          ( CCUPOL_AddrMin          ),
    .CCUPOL_AddrMax          ( CCUPOL_AddrMax          ),    
    .CCUCTR_Rst              ( CCUCTR_Rst              ),
    .CCUCTR_CfgVld           ( CCUCTR_CfgVld           ),
    .CTRCCU_CfgRdy           ( CTRCCU_CfgRdy           ),
    .CCUCTR_CfgMod           ( CCUCTR_CfgMod           ),
    .CCUCTR_CfgNip           ( CCUCTR_CfgNip           ),
    .CCUCTR_CfgNop           ( CCUCTR_CfgNop           ),
    .CCUCTR_CfgK             ( CCUCTR_CfgK             ),
    .CCUGLB_Rst              ( CCUGLB_Rst              ),
    .CCUGLB_CfgVld           ( CCUGLB_CfgVld           ),
    .GLBCCU_CfgRdy           ( GLBCCU_CfgRdy           ),
    .CCUGLB_CfgPortBankFlag  ( CCUGLB_CfgPortBankFlag  ),
    .CCUGLB_CfgPortNum  ( CCUGLB_CfgPortNum  ),
    .CCUGLB_CfgPortParBank   ( CCUGLB_CfgPortParBank )
);

GLB#(
    .NUM_BANK                ( NUM_BANK         ),
    .SRAM_WIDTH              ( SRAM_WIDTH       ),
    .SRAM_WORD               ( SRAM_WORD        ),
    .ADDR_WIDTH              ( ADDR_WIDTH       ),
    .NUM_WRPORT              ( GLB_NUM_WRPORT   ),
    .NUM_RDPORT              ( GLB_NUM_RDPORT   ),
    .MAXPAR                  ( MAXPAR           ),
    .CLOCK_PERIOD            ( CLOCK_PERIOD     ) 
)u_GLB(
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .CCUGLB_CfgVld           ( CCUGLB_CfgVld           ),
    .GLBCCU_CfgRdy           ( GLBCCU_CfgRdy           ),
    .CCUGLB_CfgPortBankFlag  ( CCUGLB_CfgPortBankFlag  ),
    .CCUGLB_CfgPortNum  ( CCUGLB_CfgPortNum  ),
    .CCUGLB_CfgPortParBank   ( CCUGLB_CfgPortParBank ),
    .WrPortDat               ( WrPortDat               ),
    .WrPortDatVld            ( WrPortDatVld            ),
    // .WrPortDatLast           ( WrPortDatLast           ),
    .WrPortDatRdy            ( WrPortDatRdy            ),
    .WrPortEmpty             ( WrPortEmpty             ),
    .WrPortReqNum            ( WrPortReqNum            ),
    .WrPortAddr_Out          ( WrPortAddr_Out          ),
    .WrPortAddrUse           ( WrPortAddrUse           ),
    .WrPortAddr              ( WrPortAddr              ),
    .RdPortDat               ( RdPortDat               ),
    .RdPortDatVld            ( RdPortDatVld            ),
    // .RdPortDatLast           ( RdPortDatLast           ),
    .RdPortDatRdy            ( RdPortDatRdy            ),
    .RdPortFull              ( RdPortFull              ),
    .RdPortReqNum            ( RdPortReqNum            ),
    .RdPortAddr_Out          ( RdPortAddr_Out          ),
    .RdPortAddrUse           ( RdPortAddrUse           ),
    .RdPortAddr              ( RdPortAddr              ),
    .RdPortAddrVld           ( RdPortAddrVld           ),
    .RdPortAddrRdy           ( RdPortAddrRdy           ) 
);

// Read Crd
assign RdPortAddrUse[GLBRDIDX_CTRCRD] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_CTRCRD +: ADDR_WIDTH] = CTRGLB_CrdAddr;
assign RdPortAddrVld[GLBRDIDX_CTRCRD] = CTRGLB_CrdAddrVld;
assign GLBCTR_CrdAddrRdy = RdPortAddrRdy[GLBRDIDX_CTRCRD];

assign GLBCTR_Crd = RdPortDat[SRAM_WIDTH*GLBRDIDX_CTRCRD +: SRAM_WIDTH];
assign GLBCTR_CrdVld = RdPortDatVld[GLBRDIDX_CTRCRD];
assign RdPortDatRdy[GLBRDIDX_CTRCRD] = CTRGLB_CrdRdy;

// Read Dist&Idx
assign RdPortAddrUse[GLBRDIDX_CTRDST] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_CTRDST +: ADDR_WIDTH] = CTRGLB_DistRdAddr;
assign RdPortAddrVld[GLBRDIDX_CTRDST] = CTRGLB_DistRdAddrVld;
assign GLBCTR_DistRdAddrRdy = RdPortAddrRdy[GLBRDIDX_CTRDST];

assign GLBCTR_DistIdx = RdPortDat[SRAM_WIDTH*GLBRDIDX_CTRDST +: SRAM_WIDTH];
assign GLBCTR_DistIdxVld = RdPortDatVld[GLBRDIDX_CTRDST];
assign RdPortDatRdy[GLBRDIDX_CTRDST] = CTRGLB_DistIdxRdy;

// Write(Update) Dist&Idx
assign WrPortAddrUse[GLBWRIDX_CTRDST] = 1'b1;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_CTRDST +: ADDR_WIDTH] = CTRGLB_DistWrAddr;

assign WrPortDat[ (SRAM_WIDTH*MAXPAR)*GLBWRIDX_CTRDST +:  (SRAM_WIDTH*MAXPAR)] = CTRGLB_DistIdx;
assign WrPortDatVld[GLBWRIDX_CTRDST] = CTRGLB_DistIdxVld;
assign GLBCTR_DistIdxRdy = WrPortDatRdy[GLBWRIDX_CTRDST];


// FPS Writes Mask to GLB
assign WrPortAddrUse[GLBWRIDX_CTRFMK] = 1'b1;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_CTRFMK +: ADDR_WIDTH] = FPSGLB_MaskWrAddr;

assign WrPortDat[ (SRAM_WIDTH*MAXPAR)*GLBWRIDX_CTRFMK +:  (SRAM_WIDTH*MAXPAR)] = FPSGLB_MaskWrDat;
assign WrPortDatVld[GLBWRIDX_CTRFMK] = FPSGLB_MaskWrDatVld;
assign GLBFPS_MaskWrDatRdy = WrPortDatRdy[GLBWRIDX_CTRFMK];

// FPS Reads Mask from GLB
assign RdPortAddrUse[GLBRDIDX_CTRFMK] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_CTRFMK +: ADDR_WIDTH] = FPSGLB_MaskRdAddr;
assign RdPortAddrVld[GLBRDIDX_CTRFMK] = FPSGLB_MaskRdAddrVld;
assign GLBFPS_MaskRdAddrRdy = RdPortAddrRdy[GLBRDIDX_CTRFMK];

assign GLBFPS_MaskRdDat = RdPortDat[SRAM_WIDTH*GLBRDIDX_CTRFMK +: SRAM_WIDTH];
assign GLBFPS_MaskRdDatVld = RdPortDatVld[GLBRDIDX_CTRFMK];
assign RdPortDatRdy[GLBRDIDX_CTRFMK] = FPSGLB_MaskRdDatRdy;

// KNN Reads Mask from GLB
assign RdPortAddrUse[GLBRDIDX_CTRKMK] = 1'b1;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_CTRKMK +: ADDR_WIDTH] = KNNGLB_MaskRdAddr;
assign RdPortAddrVld[GLBRDIDX_CTRKMK] = KNNGLB_MaskRdAddrVld;
assign GLBKNN_MaskRdAddrRdy = RdPortAddrRdy[GLBRDIDX_CTRKMK];

assign GLBKNN_MaskRdDat = RdPortDat[SRAM_WIDTH*GLBRDIDX_CTRKMK +: SRAM_WIDTH];
assign GLBKNN_MaskRdDatVld = RdPortDatVld[GLBRDIDX_CTRKMK];
assign RdPortDatRdy[GLBRDIDX_CTRKMK] = KNNGLB_MaskRdDatRdy;


// Write MAP
assign WrPortAddrUse[GLBWRIDX_CTRMAP] = 1'b0;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_CTRMAP +: ADDR_WIDTH] = 'd0;
assign WrPortDat[(SRAM_WIDTH*MAXPAR)*GLBWRIDX_CTRMAP +:  (SRAM_WIDTH*MAXPAR)] =  CTRGLB_Map;
assign WrPortDatVld[GLBWRIDX_CTRMAP] = CTRGLB_MapVld;
assign GLBCTR_MapRdy = WrPortDatRdy[GLBWRIDX_CTRMAP];

CTR#(
    .SRAM_WIDTH         ( SRAM_WIDTH    ),
    .IDX_WIDTH          ( IDX_WIDTH     ),
    .SORT_LEN_WIDTH     ( MAP_WIDTH     ),
    .CRD_WIDTH          ( CRD_WIDTH     ),
    .CRD_DIM            ( CRD_DIM       ),
    .NUM_SORT_CORE      ( NUM_SORT_CORE )
)u_CTR(
    .clk                ( clk                ),
    .rst_n              ( rst_n              ),
    .CCUCTR_Rst         ( CCUCTR_Rst         ),
    .CCUCTR_CfgVld      ( CCUCTR_CfgVld      ),
    .CTRCCU_CfgRdy      ( CTRCCU_CfgRdy      ),
    .CCUCTR_CfgMod      ( CCUCTR_CfgMod      ),
    .CCUCTR_CfgNip      ( CCUCTR_CfgNip      ),
    .CCUCTR_CfgNop      ( CCUCTR_CfgNop      ),
    .CCUCTR_CfgK        ( CCUCTR_CfgK        ),
    .CTRGLB_CrdAddr     ( CTRGLB_CrdAddr     ),
    .CTRGLB_CrdAddrVld  ( CTRGLB_CrdAddrVld  ),
    .GLBCTR_CrdAddrRdy  ( GLBCTR_CrdAddrRdy  ),
    .GLBCTR_Crd         ( GLBCTR_Crd         ),
    .GLBCTR_CrdVld      ( GLBCTR_CrdVld      ),
    .CTRGLB_CrdRdy      ( CTRGLB_CrdRdy      ),
    .CTRGLB_DistRdAddr   ( CTRGLB_DistRdAddr   ),
    .CTRGLB_DistRdAddrVld( CTRGLB_DistRdAddrVld),
    .GLBCTR_DistRdAddrRdy( GLBCTR_DistRdAddrRdy),
    .GLBCTR_DistIdx     ( GLBCTR_DistIdx[0 +: (DISTSQR_WIDTH+IDX_WIDTH)]),
    .GLBCTR_DistIdxVld  ( GLBCTR_DistIdxVld  ),
    .CTRGLB_DistIdxRdy  ( CTRGLB_DistIdxRdy  ),
    .CTRGLB_DistWrAddr  ( CTRGLB_DistWrAddr  ),
    .CTRGLB_DistIdx     ( CTRGLB_DistIdx[0 +: (DISTSQR_WIDTH+IDX_WIDTH)]     ),
    .CTRGLB_DistIdxVld  ( CTRGLB_DistIdxVld  ),
    .GLBCTR_DistIdxRdy  ( GLBCTR_DistIdxRdy  ),
    .KNNGLB_MaskRdAddr   ( KNNGLB_MaskRdAddr    ), 
    .KNNGLB_MaskRdAddrVld( KNNGLB_MaskRdAddrVld ),
    .GLBKNN_MaskRdAddrRdy( GLBKNN_MaskRdAddrRdy ),
    .GLBKNN_MaskRdDat   ( GLBKNN_MaskRdDat    ),
    .GLBKNN_MaskRdDatVld( GLBKNN_MaskRdDatVld ),
    .KNNGLB_MaskRdDatRdy   ( KNNGLB_MaskRdDatRdy    ),
    .FPSGLB_MaskRdAddr   ( FPSGLB_MaskRdAddr    ),
    .FPSGLB_MaskRdAddrVld( FPSGLB_MaskRdAddrVld ),
    .GLBFPS_MaskRdAddrRdy( GLBFPS_MaskRdAddrRdy ),
    .GLBFPS_MaskRdDat    ( GLBFPS_MaskRdDat     ),
    .GLBFPS_MaskRdDatVld ( GLBFPS_MaskRdDatVld  ),
    .FPSGLB_MaskRdDatRdy ( FPSGLB_MaskRdDatRdy  ),
    .FPSGLB_MaskWrAddr   ( FPSGLB_MaskWrAddr    ),
    .FPSGLB_MaskWrBitEn  ( FPSGLB_MaskWrBitEn   ),// ?????????????????????????????????
    .FPSGLB_MaskWrDatVld ( FPSGLB_MaskWrDatVld  ),
    .FPSGLB_MaskWrDat    ( FPSGLB_MaskWrDat     ),
    .GLBFPS_MaskWrDatRdy ( GLBFPS_MaskWrDatRdy  ),
    .CTRGLB_Map         ( CTRGLB_Map         ),
    .CTRGLB_MapVld      ( CTRGLB_MapVld      ),
    .GLBCTR_MapRdy      ( GLBCTR_MapRdy      )
);

assign RdPortAddrUse[GLBRDIDX_SYAACT] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_SYAACT] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_SYAACT +: ADDR_WIDTH] = 0;
assign GLBSYA_Act = RdPortDat[ (SRAM_WIDTH*MAXPAR)*GLBRDIDX_SYAACT +: (SRAM_WIDTH*MAXPAR)];
assign GLBSYA_ActVld = RdPortDatVld[GLBRDIDX_SYAACT];
assign RdPortDatRdy[GLBRDIDX_SYAACT] = SYAGLB_ActRdy;

assign RdPortAddrUse[GLBRDIDX_SYAWGT] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_SYAWGT] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_SYAWGT +: ADDR_WIDTH] = 0;
assign GLBSYA_Wgt = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_SYAWGT +: (SRAM_WIDTH*MAXPAR)];
assign GLBSYA_WgtVld = RdPortDatVld[GLBRDIDX_SYAWGT];
assign RdPortDatRdy[GLBRDIDX_SYAWGT] = SYAGLB_WgtRdy;

assign WrPortAddrUse[GLBWRIDX_SYAOFM] = 1'b0;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_SYAOFM +: ADDR_WIDTH] = 'd0;
assign WrPortDat[ (SRAM_WIDTH*MAXPAR)*GLBWRIDX_SYAOFM +: (SRAM_WIDTH*MAXPAR) ] = SYAGLB_Ofm;
assign WrPortDatVld[GLBWRIDX_SYAOFM] = &SYAGLB_OfmVld; // ????????????????????????????? BUG 4bit to 1 bit
assign WrPortDatLast[GLBWRIDX_SYAOFM] = 1'b0;
assign GLBSYA_OfmRdy = {NUM_BANK{WrPortDatRdy[GLBWRIDX_SYAOFM]}};

SYA #(
    .ACT_WIDTH ( ACT_WIDTH      ), 
    .WGT_WIDTH ( ACT_WIDTH      ), 
    .NUM_ROW   ( SYA_NUM_ROW    ), 
    .NUM_COL   ( SYA_NUM_COL    ), 
    .NUM_BANK  ( SYA_NUM_BANK   ), 
    .SRAM_WIDTH( SRAM_WIDTH     ),
    .CHI_WIDTH ( CHN_WIDTH      ),
    .QNT_WIDTH ( QNTSL_WIDTH    )
) u_SYA(
    .clk            (clk            ),
    .rst_n          (rst_n          ),
    .CCUSYA_Rst     (CCUSYA_Rst     ),
    .CCUSYA_CfgVld  (CCUSYA_CfgVld  ),
    .SYACCU_CfgRdy  (SYACCU_CfgRdy  ),
    .CCUSYA_CfgMod  (CCUSYA_CfgMod  ),
    .CCUSYA_CfgNip  (CCUSYA_CfgNip  ),
    .CCUSYA_CfgChi  (CCUSYA_CfgChi  ),
    .CCUSYA_CfgScale(CCUSYA_CfgScale),
    .CCUSYA_CfgShift(CCUSYA_CfgShift),
    .CCUSYA_CfgZp   (CCUSYA_CfgZp   ),
    .GLBSYA_Act     (GLBSYA_Act     ), 
    .GLBSYA_ActVld  (GLBSYA_ActVld  ),
    .SYAGLB_ActRdy  (SYAGLB_ActRdy  ),
    .GLBSYA_Wgt     (GLBSYA_Wgt     ),
    .GLBSYA_WgtVld  (GLBSYA_WgtVld  ),
    .SYAGLB_WgtRdy  (SYAGLB_WgtRdy  ),
    .SYAGLB_Ofm     (SYAGLB_Ofm     ),
    .SYAGLB_OfmVld  (SYAGLB_OfmVld  ),
    .GLBSYA_OfmRdy  (GLBSYA_OfmRdy  )
);

assign RdPortAddrUse[GLBRDIDX_POLMAP] = 1'b0;
assign RdPortAddrVld[GLBRDIDX_POLMAP] = 1'b0;
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_POLMAP +: ADDR_WIDTH] = 0;
assign GLBPOL_Map                                   = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_POLMAP +: (SRAM_WIDTH*MAXPAR)];
assign GLBPOL_MapVld                                = RdPortDatVld[GLBRDIDX_POLMAP];
assign RdPortDatRdy[GLBRDIDX_POLMAP]                = POLGLB_MapRdy;

assign RdPortAddrUse[GLBRDIDX_POLOFM +: POOL_CORE]  = {POOL_CORE{1'b1}};
assign RdPortAddr[ADDR_WIDTH*GLBRDIDX_POLOFM +: ADDR_WIDTH*POOL_CORE]= POLGLB_Addr;
assign RdPortAddrVld[GLBRDIDX_POLOFM +: POOL_CORE]  = POLGLB_AddrVld;
assign GLBPOL_AddrRdy                               = RdPortAddrRdy[GLBRDIDX_POLOFM +: POOL_CORE];

assign GLBPOL_Ofm                                   = RdPortDat[(SRAM_WIDTH*MAXPAR)*GLBRDIDX_POLOFM +: (SRAM_WIDTH*MAXPAR)*POOL_CORE];
assign GLBPOL_OfmVld                                = RdPortDatVld[GLBRDIDX_POLOFM +: POOL_CORE];
assign RdPortDatRdy[GLBRDIDX_POLOFM +: POOL_CORE]   = POLGLB_OfmRdy;

assign WrPortAddrUse[GLBWRIDX_POLOFM] = 1'b0;
assign WrPortAddr[ADDR_WIDTH*GLBWRIDX_POLOFM +: ADDR_WIDTH] = 'd0;
assign WrPortDat[(SRAM_WIDTH*MAXPAR)*GLBWRIDX_POLOFM +: (SRAM_WIDTH*MAXPAR)]= POLGLB_Ofm;
assign WrPortDatVld[GLBWRIDX_POLOFM]                = POLGLB_Ofm;
assign GLBPOL_OfmRdy                                = WrPortDatRdy[GLBWRIDX_POLOFM];


POL#(
    .IDX_WIDTH            ( IDX_WIDTH       ),
    .ACT_WIDTH            ( ACT_WIDTH       ),
    .POOL_COMP_CORE       ( POOL_COMP_CORE  ),
    .POOL_MAP_DEPTH_WIDTH ( MAP_WIDTH       ),
    .POOL_CORE            ( POOL_CORE       ),
    .CHN_WIDTH            ( CHN_WIDTH       ),
    .SRAM_WIDTH           ( SRAM_WIDTH      ) 
)u_POL(
    .clk                  ( clk                  ),
    .rst_n                ( rst_n                ),
    .CCUPOL_Rst           ( CCUPOL_Rst           ),
    .CCUPOL_CfgVld        ( CCUPOL_CfgVld        ),
    .POLCCU_CfgRdy        ( POLCCU_CfgRdy        ),
    .CCUPOL_CfgK          ( CCUPOL_CfgK          ),
    .CCUPOL_CfgNip        ( CCUPOL_CfgNip        ),
    .CCUPOL_CfgChi        ( CCUPOL_CfgChi        ),
    .CCUPOL_AddrMin       ( CCUPOL_AddrMin       ),
    .CCUPOL_AddrMax       ( CCUPOL_AddrMax       ),
    .GLBPOL_MapVld        ( GLBPOL_MapVld        ),
    .GLBPOL_Map           ( GLBPOL_Map           ),
    .POLGLB_MapRdy        ( POLGLB_MapRdy        ),
    .POLGLB_AddrVld       ( POLGLB_AddrVld       ),
    .POLGLB_Addr          ( POLGLB_Addr          ),
    .GLBPOL_AddrRdy       ( GLBPOL_AddrRdy       ),
    .GLBPOL_Ofm           ( GLBPOL_Ofm           ),
    .GLBPOL_OfmVld        ( GLBPOL_OfmVld        ),
    .POLGLB_OfmRdy        ( POLGLB_OfmRdy        ),
    .POLGLB_Ofm           ( POLGLB_Ofm           ),
    .POLGLB_OfmVld        ( POLGLB_OfmVld        ),
    .GLBPOL_OfmRdy        ( GLBPOL_OfmRdy        )
);


DELAY#(
    .NUM_STAGES ( 1 ),
    .DATA_WIDTH ( 1 )
)u_DELAY_StartPulse_Deb(
    .CLK        ( clk        ),
    .RST_N      ( rst_n      ),
    .DIN        ( StartPulse_Deb        ),
    .DOUT       ( StartPulse_Deb_d       )
);

endmodule
