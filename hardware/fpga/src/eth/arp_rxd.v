//arp rxd module
module arp_rxd (
    input                	clk        , // 
    input                	rst_n      , //��λ�źţ��͵�ƽ��Ч 
	input		[47:0]		local_mac  ,
	input		[31:0]		local_ip   ,
    input                	gmii_rxdv  ,  //GMII����������Ч�ź�
    input        [7:0]   	gmii_rxd   , //GMII��������
    output  reg          	arp_rx_done, //ARP��������ź�
    output  reg          	arp_rx_type, //ARP�������� 0:����  1:Ӧ��
    output  reg  [47:0]  	source_mac , //���յ���ԴMAC��ַ
    output  reg  [31:0]  	source_ip	  //���յ���ԴIP��ַ
);


  
  
//parameter define
localparam state_idle     = 5'b0_0001; //��ʼ״̬���ȴ�����ǰ����
localparam state_preamble = 5'b0_0010; //����ǰ����״̬ 
localparam state_eth_head = 5'b0_0100; //������̫��֡ͷ
localparam state_arp_data = 5'b0_1000; //����ARP����
localparam state_rx_end   = 5'b1_0000; //���ս���

localparam  ETH_TPYE = 16'h0806;     //��̫��֡���� ARP

//reg define
reg    [4:0]   cur_state ;
reg    [4:0]   next_state;
                         
reg            skip_en   ; //����״̬��תʹ���ź�
reg            error_en  ; //��������ʹ���ź�
reg    [4:0]   cnt       ; //�������ݼ�����
reg    [47:0]  destination_mac_t ; //���յ���Ŀ��MAC��ַ
reg    [31:0]  destination_ip_t  ; //���յ���Ŀ��IP��ַ
reg    [47:0]  source_mac_t ; //���յ���ԴMAC��ַ
reg    [31:0]  source_ip_t  ; //���յ���ԴIP��ַ
reg    [15:0]  eth_type  ; //��̫������
reg    [15:0]  op_data   ; //������

//(����ʽ״̬��)ͬ��ʱ������״̬ת��
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cur_state <=state_idle;  
    else
        cur_state <= next_state;
end

//����߼��ж�״̬ת������
always @(*) begin
    next_state =state_idle;
    case(cur_state)
       state_idle : begin                     //�ȴ�����ǰ����
            if(skip_en)next_state =state_preamble;
            else next_state =state_idle;    
        end
       state_preamble : begin                 //����ǰ����
            if(skip_en) next_state =state_eth_head;
            else if(error_en)next_state =state_rx_end;    
            else next_state =state_preamble;   
        end
       state_eth_head : begin                 //������̫��֡ͷ
            if(skip_en)next_state =state_arp_data;
            else if(error_en)next_state =state_rx_end;
            else next_state =state_eth_head;   
        end  
       state_arp_data : begin                  //����ARP����
            if(skip_en)next_state =state_rx_end;
            else if(error_en)next_state =state_rx_end;
            else next_state =state_arp_data;   
        end                  
       state_rx_end : begin                   //���ս���
            if(skip_en)next_state =state_idle;
            else next_state =state_rx_end;          
        end
        default : next_state =state_idle;
    endcase                                          
end    

//ʱ���·����״̬���,������̫������
always @(posedge clk or negedge rst_n) begin
    if(rst_n==1'b0) begin
        skip_en <= 1'b0;
        error_en <= 1'b0;
        cnt <= 5'd0;
        destination_mac_t <= 48'd0;
        destination_ip_t <= 32'd0;
        source_mac_t <= 48'd0;
        source_ip_t <= 32'd0;        
        eth_type <= 16'd0;
        op_data <= 16'd0;
        arp_rx_done <= 1'b0;
        arp_rx_type <= 1'b0;
        source_mac <= 48'd0;
        source_ip <= 32'd0;
    end
    else begin
        skip_en <= 1'b0;
        error_en <= 1'b0;  
        arp_rx_done <= 1'b0;
        case(next_state)
           state_idle : begin                                  //��⵽��һ��8'h55
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
                        destination_mac_t <= {destination_mac_t[39:0],gmii_rxd};
                    else if(cnt == 5'd6) begin
                        //�ж�MAC��ַ�Ƿ�Ϊ������MAC��ַ���߹�����ַ
                        if((destination_mac_t != local_mac) && (destination_mac_t != 48'hff_ff_ff_ff_ff_ff))           
                            error_en <= 1'b1;
                    end
                    else if(cnt == 5'd12) 
                        eth_type[15:8] <= gmii_rxd;          //��̫��Э������
                    else if(cnt == 5'd13) begin
                        eth_type[7:0] <= gmii_rxd;
                        cnt <= 5'd0;
                        if(eth_type[15:8] == ETH_TPYE[15:8]  //�ж��Ƿ�ΪARPЭ��
                            && gmii_rxd == ETH_TPYE[7:0])
                            skip_en <= 1'b1; 
                        else
                            error_en <= 1'b1;                       
                    end        
                end  
            end
           state_arp_data : begin
                if(gmii_rxdv) begin
                    cnt <= cnt + 5'd1;
                    if(cnt == 5'd6) 
                        op_data[15:8] <= gmii_rxd;           //������       
                    else if(cnt == 5'd7)
                        op_data[7:0] <= gmii_rxd;
                    else if(cnt >= 5'd8 && cnt < 5'd14)      //ԴMAC��ַ
                        source_mac_t <= {source_mac_t[39:0],gmii_rxd};
                    else if(cnt >= 5'd14 && cnt < 5'd18)     //ԴIP��ַ
                        source_ip_t<= {source_ip_t[23:0],gmii_rxd};
                    else if(cnt >= 5'd24 && cnt < 5'd28)     //Ŀ��IP��ַ
                        destination_ip_t <= {destination_ip_t[23:0],gmii_rxd};
                    else if(cnt == 5'd28) begin
                        cnt <= 5'd0;
                        if(destination_ip_t == local_ip) begin       //�ж�Ŀ��IP��ַ�Ͳ�����
                            if((op_data == 16'd1) || (op_data == 16'd2)) begin
                                skip_en 		<= 1'b1;
                                arp_rx_done 	<= 1'b1;
                                source_mac 		<= source_mac_t;
                                source_ip 		<= source_ip_t;
                                source_mac_t	<= 48'd0;
                                source_ip_t 	<= 32'd0;
                                destination_mac_t<= 48'd0;
                                destination_ip_t <= 32'd0;
                                if(op_data == 16'd1)         
                                    arp_rx_type <= 1'b0;     //ARP request
                                else
                                    arp_rx_type <= 1'b1;     //ARP ack
                            end
                            else
                                error_en <= 1'b1;
                        end 
                        else
                            error_en <= 1'b1;
                    end
                end                                
            end
           state_rx_end : begin     
                cnt <= 5'd0;
                //rx one packet done  
                if(gmii_rxdv == 1'b0 && skip_en == 1'b0)
                    skip_en <= 1'b1; 
            end    
            default : ;
        endcase                                                        
    end
end

endmodule