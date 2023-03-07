//UDP TX DATA module
module udp_txd(    
    input                clk        , //ʱ���ź�
    input                rst_n      , //��λ�źţ��͵�ƽ��Ч
    input                tx_start_en, //��̫����ʼ�����ź�
    input        [31:0]  tx_data    , //��̫������������  
    input        [15:0]  tx_byte_num, //��̫�����͵���Ч�ֽ���
    input        [47:0]  destination_mac    , //���͵�Ŀ��MAC��ַ
    input        [31:0]  destination_ip     , //���͵�Ŀ��IP��ַ  
	input		 [47:0]	 local_mac		, // ����mac
	input		 [31:0]	 local_ip		, // ����I	
    input        [31:0]  crc_data   , //CRCУ������
    input         [7:0]  crc_next   , //CRC�´�У���������
    output  reg          tx_done    , //��̫����������ź�
    output  reg          tx_request     , //�����������ź�
    output  reg          gmii_txen , //GMII���������Ч�ź�
    output  reg  [7:0]   gmii_txd   , //GMII�������
    output  reg          crc_en     , //CRC��ʼУ��ʹ��
    output  reg          crc_clear      //CRC���ݸ�λ�ź� 
    );


localparam state_idle      = 7'b000_0001; //��ʼ״̬���ȴ���ʼ�����ź�
localparam state_check_sum = 7'b000_0010; //IP�ײ�У���
localparam state_preamble  = 7'b000_0100; //����ǰ����+֡��ʼ�綨��
localparam state_eth_head  = 7'b000_1000; //������̫��֡ͷ
localparam state_ip_head   = 7'b001_0000; //����IP�ײ�+UDP�ײ�
localparam state_tx_data   = 7'b010_0000; //��������
localparam state_crc       = 7'b100_0000; //����CRCУ��ֵ

localparam  ETH_TYPE     = 16'h0800  ;  //��̫��Э������ IPЭ��
//��̫��������С46���ֽڣ�IP�ײ�20���ֽ�+UDP�ײ�8���ֽ�
//������������46-20-8=18���ֽ�
localparam  MIN_DATA_NUM = 16'd18    ;    

//reg define
reg  [6:0]   cur_state      ;
reg  [6:0]   next_state     ;
                            
reg  [7:0]   preamble[7:0]  ; //ǰ����
reg  [7:0]   eth_head[13:0] ; //��̫���ײ�
reg  [31:0]  ip_head[6:0]   ; //IP�ײ� + UDP�ײ�
                            
reg          start_en_d0    ;
reg          start_en_d1    ;
reg  [15:0]  tx_data_num    ; //���͵���Ч�����ֽڸ���
reg  [15:0]  total_num      ; //���ֽ���
reg          trig_tx_en     ;
reg  [15:0]  udp_num        ; //UDP�ֽ���
reg          skip_en        ; //����״̬��תʹ���ź�
reg  [4:0]   cnt            ;
reg  [31:0]  check_buffer   ; //�ײ�У���
reg  [1:0]   tx_bit_sel     ;
reg  [15:0]  data_cnt       ; //�������ݸ���������
reg          tx_done_reg      ;
reg  [4:0]   real_add_cnt   ; //��̫������ʵ�ʶ෢���ֽ���
                                    
//wire define                       
wire         pos_start_en    ;//��ʼ��������������
wire [15:0]  real_tx_data_num;//ʵ�ʷ��͵��ֽ���(��̫�������ֽ�Ҫ��)

assign  pos_start_en = (~start_en_d1) & start_en_d0;
assign  real_tx_data_num = (tx_data_num >= MIN_DATA_NUM) 
                           ? tx_data_num : MIN_DATA_NUM; 
                           
//��tx_start_en��������
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        start_en_d0 <= 1'b0;
        start_en_d1 <= 1'b0;
    end    
    else begin
        start_en_d0 <= tx_start_en;
        start_en_d1 <= start_en_d0;
    end
end 

//�Ĵ�������Ч�ֽ�
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        tx_data_num <= 16'd0;
        total_num <= 16'd0;
        udp_num <= 16'd0;
    end
    else begin
        if(pos_start_en && cur_state==state_idle) begin
            //���ݳ���
            tx_data_num <= tx_byte_num;        
            //IP���ȣ���Ч����+IP�ײ�����            
            total_num <= tx_byte_num + 16'd28;  
            //UDP���ȣ���Ч����+UDP�ײ�����            
            udp_num <= tx_byte_num + 16'd8;               
        end    
    end
end

//���������ź�
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) 
        trig_tx_en <= 1'b0;
    else
        trig_tx_en <= pos_start_en;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)cur_state <=state_idle;  
    else cur_state <= next_state;
end

always @(*) begin
    next_state =state_idle;
    case(cur_state)
       state_idle     : begin                               //�ȴ���������
            if(skip_en)                
                next_state =state_check_sum;
            else
                next_state =state_idle;
        end  
       state_check_sum: begin                               //IP�ײ�У��
            if(skip_en)
                next_state =state_preamble;
            else
                next_state =state_check_sum;    
        end                             
       state_preamble : begin                               //����ǰ����+֡��ʼ�綨��
            if(skip_en)
                next_state =state_eth_head;
            else
                next_state =state_preamble;      
        end
       state_eth_head : begin                               //������̫���ײ�
            if(skip_en)
                next_state =state_ip_head;
            else
                next_state =state_eth_head;      
        end              
       state_ip_head : begin                                //����IP�ײ�+UDP�ײ�               
            if(skip_en)
                next_state =state_tx_data;
            else
                next_state =state_ip_head;      
        end
       state_tx_data : begin                                //��������                  
            if(skip_en)
                next_state =state_crc;
            else
                next_state =state_tx_data;      
        end
       state_crc: begin                                     //����CRCУ��ֵ
            if(skip_en)
                next_state =state_idle;
            else
                next_state =state_crc;      
        end
        default : next_state =state_idle;   
    endcase
end                      

//TX DATA
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        skip_en <= 1'b0; 
        cnt <= 5'd0;
        check_buffer <= 32'd0;
        ip_head[1][31:16] <= 16'd0;
        tx_bit_sel <= 2'b0;
        crc_en <= 1'b0;
        gmii_txen <= 1'b0;
        gmii_txd <= 8'd0;
        tx_request <= 1'b0;
        tx_done_reg <= 1'b0; 
        data_cnt <= 16'd0;
        real_add_cnt <= 5'd0;    
        //ǰ���� 7��8'h55 + 1��8'hd5
        preamble[0] <= 8'h55;                 
        preamble[1] <= 8'h55;
        preamble[2] <= 8'h55;
        preamble[3] <= 8'h55;
        preamble[4] <= 8'h55;
        preamble[5] <= 8'h55;
        preamble[6] <= 8'h55;
        preamble[7] <= 8'hd5;
        //Ŀ��MAC��ַ
        eth_head[0] <=0;
        eth_head[1] <=0;
        eth_head[2] <=0;
        eth_head[3] <=0;
        eth_head[4] <=0;
        eth_head[5] <=0;
        //ԴMAC��ַ
        eth_head[6] <= 0;
        eth_head[7] <= 0;
        eth_head[8] <= 0;
        eth_head[9] <= 0;
        eth_head[10] <= 0;
        eth_head[11] <= 0;
        //��̫������
        eth_head[12] <= ETH_TYPE[15:8];
        eth_head[13] <= ETH_TYPE[7:0];        
    end
    else begin
        skip_en <= 1'b0;
        tx_request <= 1'b0;
        crc_en <= 1'b0;
        gmii_txen <= 1'b0;
        tx_done_reg <= 1'b0;
        case(next_state)
           state_idle     : begin
                if(trig_tx_en) begin
                    skip_en <= 1'b1; 
                    //�汾��4 �ײ�����5(��λ:32bit,20byte/4=5)
                    ip_head[0] <= {8'h45,8'h00,total_num};   
                    //16λ��ʶ��ÿ�η����ۼ�1      
                    ip_head[1][31:16] <= ip_head[1][31:16] + 1'b1; 
                    //bit[15:13]: 010��ʾ����Ƭ
                    ip_head[1][15:0] <= 16'h4000;    
                    //Э�飺17(udp)                  
                    ip_head[2] <= {8'h40,8'd17,16'h0};   
                    //ԴIP��ַ               
                    ip_head[3] <= local_ip;
                    //Ŀ��IP��ַ    
                    if(destination_ip != 32'd0) ip_head[4] <= destination_ip;
                    else ip_head[4] <= destination_ip;       
                    //16λԴ�˿ںţ�1234  16λĿ�Ķ˿ںţ�1234                      
                    ip_head[5] <= {16'd1234,16'd1234};  
                    //16λudp���ȣ�16λudpУ���              
                    ip_head[6] <= {udp_num,16'h0000};  
                    //����MAC��ַ
                    if(destination_mac != 48'b0) begin
                        //Ŀ��MAC��ַ
                        eth_head[0] <= destination_mac[47:40];
                        eth_head[1] <= destination_mac[39:32];
                        eth_head[2] <= destination_mac[31:24];
                        eth_head[3] <= destination_mac[23:16];
                        eth_head[4] <= destination_mac[15:8];
                        eth_head[5] <= destination_mac[7:0];
						
						        //ԴMAC��ַ
						eth_head[6]  <= local_mac[47:40];
						eth_head[7]  <= local_mac[39:32];
						eth_head[8]  <= local_mac[31:24];
						eth_head[9]  <= local_mac[23:16];
						eth_head[10] <= local_mac[15:8];
						eth_head[11] <= local_mac[7:0];
                    end
                end    
            end                                                       
           state_check_sum: begin                           //IP�ײ�У��
                cnt <= cnt + 5'd1;
                if(cnt == 5'd0) begin                   
                    check_buffer <= ip_head[0][31:16] + ip_head[0][15:0]
                                    + ip_head[1][31:16] + ip_head[1][15:0]
                                    + ip_head[2][31:16] + ip_head[2][15:0]
                                    + ip_head[3][31:16] + ip_head[3][15:0]
                                    + ip_head[4][31:16] + ip_head[4][15:0];
                end
                else if(cnt == 5'd1)                      //���ܳ��ֽ�λ,�ۼ�һ��
                    check_buffer <= check_buffer[31:16] + check_buffer[15:0];
                else if(cnt == 5'd2) begin                //�����ٴγ��ֽ�λ,�ۼ�һ��
                    check_buffer <= check_buffer[31:16] + check_buffer[15:0];
                end                             
                else if(cnt == 5'd3) begin                //��λȡ�� 
                    skip_en <= 1'b1;
                    cnt <= 5'd0;            
                    ip_head[2][15:0] <= ~check_buffer[15:0];
                end    
            end              
           state_preamble : begin                           //����ǰ����+֡��ʼ�綨��
                gmii_txen <= 1'b1;
                gmii_txd <= preamble[cnt];
                if(cnt == 5'd7) begin                        
                    skip_en <= 1'b1;
                    cnt <= 5'd0;    
                end
                else    
                    cnt <= cnt + 5'd1;                     
            end
           state_eth_head : begin                           //������̫���ײ�
                gmii_txen <= 1'b1;
                crc_en <= 1'b1;
                gmii_txd <= eth_head[cnt];
                if (cnt == 5'd13) begin
                    skip_en <= 1'b1;
                    cnt <= 5'd0;
                end    
                else    
                    cnt <= cnt + 5'd1;    
            end                    
           state_ip_head  : begin                           //����IP�ײ� + UDP�ײ�
                crc_en <= 1'b1;
                gmii_txen <= 1'b1;
                tx_bit_sel <= tx_bit_sel + 2'd1;
                if(tx_bit_sel == 3'd0)
                    gmii_txd <= ip_head[cnt][31:24];
                else if(tx_bit_sel == 3'd1)
                    gmii_txd <= ip_head[cnt][23:16];
                else if(tx_bit_sel == 3'd2) begin
                    gmii_txd <= ip_head[cnt][15:8];
                    if(cnt == 5'd6) begin
                        //��ǰ���������ݣ��ȴ�������Чʱ����
                        tx_request <= 1'b1;                     
                    end
                end 
                else if(tx_bit_sel == 3'd3) begin
                    gmii_txd <= ip_head[cnt][7:0];  
                    if(cnt == 5'd6) begin
                        skip_en <= 1'b1;   
                        cnt <= 5'd0;
                    end    
                    else
                        cnt <= cnt + 5'd1;  
                end        
            end
           state_tx_data  : begin                           //��������
                crc_en <= 1'b1;
                gmii_txen <= 1'b1;
                tx_bit_sel <= tx_bit_sel + 3'd1;  
                if(data_cnt < tx_data_num - 16'd1)
                    data_cnt <= data_cnt + 16'd1;                        
                else if(data_cnt == tx_data_num - 16'd1)begin
                    //������͵���Ч��������18���ֽڣ��ں������λ
                    //�����ֵΪ���һ�η��͵���Ч����
                    gmii_txd <= 8'd0;
                    if(data_cnt + real_add_cnt < real_tx_data_num - 16'd1)
                        real_add_cnt <= real_add_cnt + 5'd1;  
                    else begin
                        skip_en <= 1'b1;
                        data_cnt <= 16'd0;
                        real_add_cnt <= 5'd0;
                        tx_bit_sel <= 3'd0;                        
                    end    
                end
                if(tx_bit_sel == 1'b0)
                    gmii_txd <= tx_data[31:24];
                else if(tx_bit_sel == 3'd1)
                    gmii_txd <= tx_data[23:16];                   
                else if(tx_bit_sel == 3'd2) begin
                    gmii_txd <= tx_data[15:8];   
                    if(data_cnt != tx_data_num - 16'd1)
                        tx_request <= 1'b1;  
                end
                else if(tx_bit_sel == 3'd3)
                    gmii_txd <= tx_data[7:0];                                                                                                
            end  
           state_crc      : begin                          //����CRCУ��ֵ
                gmii_txen <= 1'b1;
                tx_bit_sel <= tx_bit_sel + 3'd1;
                if(tx_bit_sel == 3'd0)
                    gmii_txd <= {~crc_next[0], ~crc_next[1], ~crc_next[2],~crc_next[3],
                                 ~crc_next[4], ~crc_next[5], ~crc_next[6],~crc_next[7]};
                else if(tx_bit_sel == 3'd1)
                    gmii_txd <= {~crc_data[16], ~crc_data[17], ~crc_data[18],~crc_data[19],
                                 ~crc_data[20], ~crc_data[21], ~crc_data[22],~crc_data[23]};
                else if(tx_bit_sel == 3'd2) begin
                    gmii_txd <= {~crc_data[8], ~crc_data[9], ~crc_data[10],~crc_data[11],
                                 ~crc_data[12], ~crc_data[13], ~crc_data[14],~crc_data[15]};                              
                end
                else if(tx_bit_sel == 3'd3) begin
                    gmii_txd <= {~crc_data[0], ~crc_data[1], ~crc_data[2],~crc_data[3],
                                 ~crc_data[4], ~crc_data[5], ~crc_data[6],~crc_data[7]};  
                    tx_done_reg <= 1'b1;
                    skip_en <= 1'b1;
                end                                                                                                                                            
            end                          
            default :;  
        endcase                                             
    end
end            

//��������źż�crcֵ��λ�ź�
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        tx_done <= 1'b0;
        crc_clear <= 1'b0;
    end
    else begin
        tx_done <= tx_done_reg;
        crc_clear <= tx_done_reg;
    end
end

endmodule

