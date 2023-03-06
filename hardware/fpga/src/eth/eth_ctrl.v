//eth control module
module eth_ctrl(
    input              clk       ,    //ϵͳʱ��
    input              rst_n     ,    //ϵͳ��λ�źţ��͵�ƽ��Ч 

	//module top
	input				tx_start_en, 
	input	[47:0]		tx_des_mac,

    //arp port                                 
    input              arp_rx_done,   //ARP��������ź�
    input              arp_rx_type,   //ARP�������� 0:����  1:Ӧ��
    output  reg        arp_tx_en,     //ARP����ʹ���ź�
    output  reg        arp_tx_type =0,   //ARP�������� 0:����  1:Ӧ��
    input              arp_tx_done,   //ARP��������ź�

    //gmii tx data 
    input              arp_gmii_txen,//ARP GMII���������Ч�ź� 
    input     [7:0]    arp_gmii_txd,  //ARP GMII�������
	
    input              udp_gmii_txen,//UDP GMII���������Ч�ź�  
    input     [7:0]    udp_gmii_txd,  //UDP GMII�������   
    output             gmii_txen,    //GMII���������Ч�ź� 
    output    [7:0]    gmii_txd,       //UDP GMII������� 
    output             gmii_tlast       //UDP GMII������� 
);

//indicate whitch protocal
reg        udp_protocol; //Э���л��ź�
wire  arp_tx_en_temp   =  (arp_rx_done && (arp_rx_type == 1'b0)) || // �Է�������arp����
					      (tx_start_en && (tx_des_mac == 48'b0));  	// ����Է�arp����
// assign gmii_txen = udp_protocol ? udp_gmii_txen : arp_gmii_txen;
// assign gmii_txd  = udp_protocol ? udp_gmii_txd : arp_gmii_txd;

//����ARP����ʹ��/����ź�,�л�GMII����
always @(posedge clk) begin
    if(rst_n==1'b0)           
		udp_protocol <= 1'b1;
    else if(arp_tx_en_temp)   
		udp_protocol <= 1'b0;
    else if(arp_tx_done) 
		udp_protocol <= 1'b1;
	else 
		udp_protocol <= udp_protocol;
end

always @(posedge clk) begin
	arp_tx_en <= arp_tx_en_temp;
	
	if((arp_rx_done && (arp_rx_type == 1'b0))) // arp request
		arp_tx_type	<= 1; 	// ���� 1:Ӧ��
	else if(tx_start_en && (tx_des_mac == 48'b0)) // arp response
		arp_tx_type	<= 0; 	// ���� 0:���� 
	else 
		arp_tx_type <= arp_tx_type;
end

/***********************************************/
reg gmii_txen_f;
reg [7:0] gmii_txd_f;
wire temp = udp_protocol ? udp_gmii_txen : arp_gmii_txen;

always @(posedge clk) begin
	gmii_txen_f <= temp;
	gmii_txd_f <=  udp_protocol ? udp_gmii_txd : arp_gmii_txd;
end

assign gmii_txen = gmii_txen_f;
assign gmii_txd  = gmii_txd_f;
assign gmii_tlast = (~temp) & gmii_txen_f;
endmodule