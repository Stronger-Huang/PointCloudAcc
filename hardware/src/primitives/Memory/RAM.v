module RAM #(
    parameter SRAM_BIT          = 128,
    parameter SRAM_BYTE         = 1,
    parameter SRAM_WORD         = 64,
    parameter DUAL_PORT         = 0,
    
    parameter SRAM_WIDTH        = SRAM_BIT*SRAM_BYTE,
    parameter SRAM_ADDR_WIDTH   = $clog2(SRAM_WORD)

)(
    input                           clk     ,
    input                           rst_n   ,
    input [SRAM_ADDR_WIDTH  -1 : 0] addr_r  ,
    input [SRAM_ADDR_WIDTH  -1 : 0] addr_w  ,
    input                           read_en ,
    input                           write_en,
    input [SRAM_WIDTH       -1 : 0] data_in ,
    output[SRAM_WIDTH       -1 : 0] data_out 
);          

`ifdef FUNC_SIM
    RAM_REG#(
        .SRAM_ADDR_WIDTH ( SRAM_ADDR_WIDTH  ),
        .SRAM_WIDTH      ( SRAM_WIDTH       )
    )u_RAM_REG(
        .clk            ( clk       ),
        .read_en        ( read_en   ),
        .write_en       ( write_en  ),
        .addr_r         ( addr_r    ),
        .addr_w         ( addr_w    ),
        .data_in        ( data_in   ),
        .data_out       ( data_out  )
    );
`else
    `ifdef SIM
        parameter DELAY = `CLOCK_PERIOD/2;
    `else
        parameter DELAY = 0;
    `endif

    wire [ SRAM_ADDR_WIDTH          -1 : 0] AR; // Read Addr
    wire [ SRAM_ADDR_WIDTH          -1 : 0] AW;
    wire [ SRAM_WIDTH               -1 : 0] DI;
    wire [ SRAM_BYTE                -1 : 0] WEB;
    wire                                    CSB;
    wire [2                         -1 : 0] RTSEL;
    wire [2                         -1 : 0] WTSEL;
    wire [2                         -1 : 0] PTSEL;

    assign #(DELAY) AR   = addr_r;
    assign #(DELAY) AW   = addr_w;
    assign #(DELAY) DI   = data_in;
    assign #(DELAY) WEB  = {SRAM_BYTE{~write_en}};
    assign #(DELAY) CSB  = (~write_en)&(~read_en);

    assign #(DELAY) WTSEL= 2'b00;
    assign #(DELAY) PTSEL= 2'b00;

    // Lock DO
    wire [ SRAM_WIDTH              -1 : 0] DO;
    wire                                   read_en_d;
    reg  [ SRAM_WIDTH              -1 : 0] DO_d;
    DELAY #(
        .NUM_STAGES(1),
        .DATA_WIDTH(1)
    ) Delay_read_en_d (
        .CLK     (clk       ),
        .RST_N   (rst_n     ),
        .DIN     (read_en   ),
        .DOUT    (read_en_d )
    );
    always @ ( posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            DO_d <= 0;
        end else if( read_en_d) begin
            DO_d <= DO;
        end
    end
    assign data_out = read_en_d? DO : DO_d;

    `define RTSELDB
    generate
        if( SRAM_WORD == 128 && SRAM_BIT == 256 && SRAM_BYTE == 1 && DUAL_PORT == 0)begin
            `ifdef RTSELDB
                assign #(DELAY) RTSEL= 2'b10;
            `else
                assign #(DELAY) RTSEL= 2'b00;
            `endif
            TS1N28HPCPUHDHVTB128X256M1SSO GLB_BANK(
            .SLP    ( 1'b0  ),
            .SD     ( 1'b0  ),
            .CLK    ( clk   ),
            .CEB    ( CSB   ),
            .WEB    ( WEB   ),
            .A      ( (&WEB)? AR : AW ),
            .D      ( DI    ),
            .RTSEL  ( RTSEL ),
            .WTSEL  ( WTSEL ),
            .Q      ( DO    )
            );
        end
        else if( SRAM_WORD == 256 && SRAM_BIT == 8 && SRAM_BYTE == 1 && DUAL_PORT == 0)begin
            assign #(DELAY) RTSEL= 2'b00;
            TS1N28HPCPUHDHVTB256X8M4SSO SHF_SPRAM(
            .SLP    ( 1'b0  ),
            .SD     ( 1'b0  ),
            .CLK    ( clk   ),
            .CEB    ( CSB   ),
            .WEB    ( WEB   ),
            .A      ( (&WEB)? AR : AW     ),
            .D      ( DI    ),
            .RTSEL  ( RTSEL ),
            .WTSEL  ( WTSEL ),
            .Q      ( DO    )
            );
        end
        else if( SRAM_WORD == 64 && SRAM_BIT == 512 && SRAM_BYTE == 1 && DUAL_PORT == 0)begin
            `ifdef RTSELDB
                assign #(DELAY) RTSEL= 2'b10;
            `else
                assign #(DELAY) RTSEL= 2'b00;
            `endif
            TS1N28HPCPUHDHVTB64X256M1SSO SYA_FWFT_SPSRAM0(
            .SLP    ( 1'b0  ),
            .SD     ( 1'b0  ),
            .CLK    ( clk   ),
            .CEB    ( CSB   ),
            .WEB    ( WEB   ),
            .A      ( (&WEB)? AR : AW   ),
            .D      ( DI[0 +: SRAM_BIT/2] ),
            .RTSEL  ( RTSEL ),
            .WTSEL  ( WTSEL ),
            .Q      ( DO[0 +: SRAM_BIT/2] )
            );
            TS1N28HPCPUHDHVTB64X256M1SSO SYA_FWFT_SPSRAM1(
            .SLP    ( 1'b0  ),
            .SD     ( 1'b0  ),
            .CLK    ( clk   ),
            .CEB    ( CSB   ),
            .WEB    ( WEB   ),
            .A      ( (&WEB)? AR : AW   ),
            .D      ( DI[SRAM_BIT/2 +: SRAM_BIT/2]),
            .RTSEL  ( RTSEL ),
            .WTSEL  ( WTSEL ),
            .Q      ( DO[SRAM_BIT/2 +: SRAM_BIT/2])
            );
        end
    endgenerate

`endif


endmodule
