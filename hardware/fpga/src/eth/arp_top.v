//arp module top
module arp_top(
    input                rst_n      	, //��λ�źţ��͵�ƽ��Ч
    //GMII
    input                gmii_rxc		, //GMII��������ʱ��
    input                gmii_rxdv 		, //GMII����������Ч�ź�
    input        [7:0]   gmii_rxd   	, //GMII��������
    input                gmii_txc		, //GMII��������ʱ��
    output               gmii_txen 		, //GMII���������Ч�ź�
    output       [7:0]   gmii_txd   	, //GMII�������  
	
    //arp port
    output               arp_rx_done	, //ARP��������ź�
    output               arp_rx_type	, //ARP�������� 0:����  1:Ӧ��
    output       [47:0]  source_mac     , //���յ�Ŀ��MAC��ַ
    output       [31:0]  source_ip      , //���յ�Ŀ��IP��ַ   
	
    input                arp_tx_en  	, //ARP����ʹ���ź�
    input                arp_tx_type	, //ARP�������� 0:����  1:Ӧ��
	
    input        [47:0]  destination_mac, //���͵�Ŀ��MAC��ַ
    input        [31:0]  desination_ip  , //���͵�Ŀ��IP��ַ
	input		 [47:0]	 local_mac		, // ����mac
	input		 [31:0]	 local_ip		, // ����IP
    output               tx_done     	  //��̫����������ź�    
    );


//wire
wire           crc_en  ; //CRC��ʼУ��ʹ��
wire           crc_clear ; //CRC���ݸ�λ�ź� 
wire   [7:0]   crc_d8  ; //�����У��8λ����
wire   [31:0]  crc_data; //CRCУ������
wire   [31:0]  crc_next; //CRC�´�У���������

assign  crc_d8 = gmii_txd;

//ARP����ģ��    
arp_rxd arp_rxd_inst(		
    .clk             	(gmii_rxc			),
    .rst_n           	(rst_n				),
	.local_mac			(local_mac			),
	.local_ip			(local_ip			),	
    .gmii_rxdv       	(gmii_rxdv			),
    .gmii_rxd        	(gmii_rxd  			),
    .arp_rx_done     	(arp_rx_done		),
    .arp_rx_type     	(arp_rx_type		),
    .source_mac      	(source_mac    		),
    .source_ip       	(source_ip     		)
);                                           

//ARP TXD module
arp_txd  arp_txd_inst(	
    .clk            	(gmii_txc			),
    .rst_n          	(rst_n				),
	.local_mac			(local_mac			),
	.local_ip			(local_ip			),
    .arp_tx_en      	(arp_tx_en 			),
    .arp_tx_type    	(arp_tx_type		),
    .destination_mac	(destination_mac	),
    .destination_ip		(desination_ip		),
    .crc_data        	(crc_data  			),
    .crc_next        	(crc_next[31:24]	),
    .tx_done         	(tx_done   			),
    .gmii_txen      	(gmii_txen			),
    .gmii_txd        	(gmii_txd  			),
    .crc_en          	(crc_en    			),
    .crc_clear         	(crc_clear   		)
);     

// data packet crc ,do crc32
crc32   crc32_inst(
    .clk             	(gmii_txc		),                      
    .rst_n           	(rst_n      	),                          
    .data_in         	(crc_d8     	),            
    .crc_en          	(crc_en     	),                          
    .crc_clear			(crc_clear    	),                         
    .crc_data        	(crc_data   	),                        
    .crc_next        	(crc_next   	)                         
);

endmodule
