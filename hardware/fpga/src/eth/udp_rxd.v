//UDP RX DATA module
module udp_rxd(
    input                clk         ,    //ʱ���ź�
    input                rst_n       ,    //��λ�źţ��͵�ƽ��Ч
	input		 [47:0]	 local_mac		, // ����mac
	input		 [31:0]	 local_ip		, // ����IP		
    input                gmii_rxdv  ,    //GMII����������Ч�ź�
    input        [7:0]   gmii_rxd    ,    //GMII��������
    output  reg          rxd_pkt_done,    //��̫���������ݽ�������ź�
    output  reg          rxd_wr_en      ,    //��̫�����յ�����ʹ���ź�
    output  reg  [31:0]  rxd_wr_data    ,    //��̫�����յ�����
    output  reg  [15:0]  rxd_wr_byte_num     //��̫�����յ���Ч���� ��λ:byte     
);


localparam state_idle     = 7'b000_0001; //��ʼ״̬���ȴ�����ǰ����
localparam state_preamble = 7'b000_0010; //����ǰ����״̬ 
localparam state_eth_head = 7'b000_0100; //������̫��֡ͷ
localparam state_ip_head  = 7'b000_1000; //����IP�ײ�
localparam state_udp_head = 7'b001_0000; //����UDP�ײ�
localparam state_rx_data  = 7'b010_0000; //������Ч����
localparam state_rx_end   = 7'b100_0000; //���ս���

localparam  ETH_TYPE    = 16'h0800   ; //��̫��Э������ IPЭ��

//reg define
reg  [6:0]   cur_state       ;
reg  [6:0]   next_state      ;
                             
reg          skip_en         ; //����״̬��תʹ���ź�
reg          error_en        ; //��������ʹ���ź�
reg  [4:0]   cnt             ; //�������ݼ�����
reg  [47:0]  destination_mac ; //Ŀ��MAC��ַ
reg  [15:0]  eth_type        ; //��̫������
reg  [31:0]  destination_ip  ; //Ŀ��IP��ַ
reg  [5:0]   ip_head_byte_num; //IP�ײ�����
reg  [15:0]  udp_byte_num    ; //UDP����
reg  [15:0]  data_byte_num   ; //���ݳ���
reg  [15:0]  data_cnt        ; //��Ч���ݼ���    
reg  [1:0]   rxd_wr_en_cnt      ; //8bitת32bit������

//(����ʽ״̬��)ͬ��ʱ������״̬ת��
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0)cur_state <=state_idle;  
    else cur_state <= next_state;
end

//����߼��ж�״̬ת������
always @(*) begin
    next_state =state_idle;
    case(cur_state)
       state_idle : begin                                     //�ȴ�����ǰ����
            if(skip_en)  next_state =state_preamble;
            else next_state =state_idle;    
        end
       state_preamble : begin                                 //����ǰ����
            if(skip_en)  next_state =state_eth_head;
            else if(error_en) next_state =state_rx_end;    
            else next_state =state_preamble;    
        end
       state_eth_head : begin                                 //������̫��֡ͷ
            if(skip_en) next_state =state_ip_head;
            else if(error_en) next_state =state_rx_end;
            else next_state =state_eth_head;           
        end  
       state_ip_head : begin                                  //����IP�ײ�
            if(skip_en)next_state =state_udp_head;
            else if(error_en) next_state =state_rx_end;
            else next_state =state_ip_head;       
        end 
       state_udp_head : begin                                 //����UDP�ײ�
            if(skip_en)next_state =state_rx_data;
            else next_state =state_udp_head;    
        end                
       state_rx_data : begin                                  //������Ч����
            if(skip_en) next_state =state_rx_end;
            else next_state =state_rx_data;    
        end                           
       state_rx_end : begin                                   //���ս���
            if(skip_en)next_state =state_idle;
            else next_state =state_rx_end;          
        end
        default : next_state =state_idle;
    endcase                                          
end    

//��������
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        skip_en <= 1'b0;
        error_en <= 1'b0;
        cnt <= 5'd0;
        destination_mac <= 48'd0;
        eth_type <= 16'd0;
        destination_ip <= 32'd0;
        ip_head_byte_num <= 6'd0;
        udp_byte_num <= 16'd0;
        data_byte_num <= 16'd0;
        data_cnt <= 16'd0;
        rxd_wr_en_cnt <= 2'd0;
        rxd_wr_en <= 1'b0;
        rxd_wr_data <= 32'd0;
        rxd_pkt_done <= 1'b0;
        rxd_wr_byte_num <= 16'd0;
    end
    else begin
        skip_en <= 1'b0;
        error_en <= 1'b0;  
        rxd_wr_en <= 1'b0;
        rxd_pkt_done <= 1'b0;
        case(next_state)
           state_idle : begin
                if((gmii_rxdv == 1'b1) && (gmii_rxd == 8'h55)) 
                    skip_en <= 1'b1;
            end
           state_preamble : begin
                if(gmii_rxdv) begin                         //����ǰ����
                    cnt <= cnt + 5'd1;
                    if((cnt < 5'd6) && (gmii_rxd != 8'h55))  //7��8'h55  
                        error_en <= 1'b1;
                    else if(cnt==5'd6) begin
                        cnt <= 5'd0;
                        if(gmii_rxd==8'hd5)                  //1��8'hd5
                            skip_en <= 1'b1;
                        else
                            error_en <= 1'b1;    
                    end  
                end  
            end
           state_eth_head : begin
                if(gmii_rxdv) begin
                    cnt <= cnt + 5'b1;
                    if(cnt < 5'd6) 
                        destination_mac <= {destination_mac[39:0],gmii_rxd}; //Ŀ��MAC��ַ
                    else if(cnt == 5'd12) 
                        eth_type[15:8] <= gmii_rxd;          //��̫��Э������
                    else if(cnt == 5'd13) begin
                        eth_type[7:0] <= gmii_rxd;
                        cnt <= 5'd0;
                        //�ж�MAC��ַ�Ƿ�Ϊ������MAC��ַ���߹�����ַ
                        if(((destination_mac == local_mac) ||(destination_mac == 48'hff_ff_ff_ff_ff_ff))
                       && eth_type[15:8] == ETH_TYPE[15:8] && gmii_rxd == ETH_TYPE[7:0])            
                            skip_en <= 1'b1;
                        else
                            error_en <= 1'b1;
                    end        
                end  
            end
           state_ip_head : begin
                if(gmii_rxdv) begin
                    cnt <= cnt + 5'd1;
                    if(cnt == 5'd0)
                        ip_head_byte_num <= {gmii_rxd[3:0],2'd0};
                    else if((cnt >= 5'd16) && (cnt <= 5'd18))
                        destination_ip <= {destination_ip[23:0],gmii_rxd};   //Ŀ��IP��ַ
                    else if(cnt == 5'd19) begin
                        destination_ip <= {destination_ip[23:0],gmii_rxd}; 
                        //�ж�IP��ַ�Ƿ�Ϊ������IP��ַ
                        if((destination_ip[23:0] == local_ip[31:8])
                            && (gmii_rxd == local_ip[7:0])) begin  
                            if(cnt == ip_head_byte_num - 1'b1) begin
                                skip_en <=1'b1;                     
                                cnt <= 5'd0;
                            end                             
                        end    
                        else begin            
                        //IP����ֹͣ��������                        
                            error_en <= 1'b1;               
                            cnt <= 5'd0;
                        end                                                  
                    end                          
                    else if(cnt == ip_head_byte_num - 1'b1) begin 
                        skip_en <=1'b1;                      //IP�ײ��������
                        cnt <= 5'd0;                    
                    end    
                end                                
            end 
           state_udp_head : begin
                if(gmii_rxdv) begin
                    cnt <= cnt + 5'd1;
                    if(cnt == 5'd4)
                        udp_byte_num[15:8] <= gmii_rxd;      //����UDP�ֽڳ��� 
                    else if(cnt == 5'd5)
                        udp_byte_num[7:0] <= gmii_rxd;
                    else if(cnt == 5'd7) begin
                        //��Ч�����ֽڳ��ȣ���UDP�ײ�8���ֽڣ����Լ�ȥ8��
                        data_byte_num <= udp_byte_num - 16'd8;    
                        skip_en <= 1'b1;
                        cnt <= 5'd0;
                    end  
                end                 
            end          
           state_rx_data : begin         
                //�������ݣ�ת����32bit            
                if(gmii_rxdv) begin
                    data_cnt <= data_cnt + 16'd1;
                    rxd_wr_en_cnt <= rxd_wr_en_cnt + 2'd1;
                    if(data_cnt == data_byte_num - 16'd1) begin
                        skip_en <= 1'b1;                    //��Ч���ݽ������
                        data_cnt <= 16'd0;
                        rxd_wr_en_cnt <= 2'd0;
                        rxd_pkt_done <= 1'b1;               
                        rxd_wr_en <= 1'b1;                     
                        rxd_wr_byte_num <= data_byte_num;
                    end    
                    //���յ������ݷ���rxd_wr_data�ĸ�λ,�����ݲ���4�ı���ʱ,
                    //��λ����Ϊ��Ч���ݣ�������Ч�ֽ������ж�(rxd_wr_byte_num)
                    if(rxd_wr_en_cnt == 2'd0)
                        rxd_wr_data[31:24] <= gmii_rxd;
                    else if(rxd_wr_en_cnt == 2'd1)
                        rxd_wr_data[23:16] <= gmii_rxd;
                    else if(rxd_wr_en_cnt == 2'd2) 
                        rxd_wr_data[15:8] <= gmii_rxd;        
                    else if(rxd_wr_en_cnt==2'd3) begin
                        rxd_wr_en <= 1'b1;
                        rxd_wr_data[7:0] <= gmii_rxd;
                    end    
                end  
            end    
           state_rx_end : begin //�������ݽ������   
                if(gmii_rxdv == 1'b0 && skip_en == 1'b0)
                    skip_en <= 1'b1; 
            end    
            default : ;
        endcase                                                        
    end
end


endmodule