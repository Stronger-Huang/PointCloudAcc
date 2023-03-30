//UDP Top module
module udp_top(
    input                rst_n       , //��λ�źţ��͵�ƽ��Ч
    //GMII
    input                gmii_rxc , //GMII��������ʱ��
    input                gmii_rxdv  , //GMII����������Ч�ź�
    input        [7:0]   gmii_rxd    , //GMII��������
    input                gmii_txc , //GMII��������ʱ��    
    output               gmii_txen  , //GMII���������Ч�ź�
    output       [7:0]   gmii_txd    , //GMII������� 
    // udp port
    output               rxd_pkt_done, //��̫���������ݽ�������ź�
    output               rxd_wr_en      , //��̫�����յ�����ʹ���ź�
    output       [31:0]  rxd_wr_data    , //��̫�����յ�����
    output       [15:0]  rxd_wr_byte_num, //��̫�����յ���Ч�ֽ��� ��λ:byte     
    input                tx_start_en , //��̫����ʼ�����ź�
    input        [31:0]  tx_data     , //��̫������������  
    input        [15:0]  tx_byte_num , //��̫�����͵���Ч�ֽ��� ��λ:byte  
    input        [47:0]  destination_mac     , //���͵�Ŀ��MAC��ַ
    input        [31:0]  destination_ip      , //���͵�Ŀ��IP��ַ 
	input		 [47:0]	 local_mac		, // ����mac
	input		 [31:0]	 local_ip		, // ����IP	
    output               tx_done     , //��̫����������ź�
    output               tx_request        //�����������ź�    
    );


//wire define
wire          crc_en  ; //CRC��ʼУ��ʹ��
wire          crc_clear ; //CRC���ݸ�λ�ź� 
wire  [7:0]   crc_d8  ; //�����У��8λ����

wire  [31:0]  crc_data; //CRCУ������
wire  [31:0]  crc_next; //CRC�´�У���������

assign  crc_d8 = gmii_txd;

// UDP RXD  module
udp_rxd   udp_rx_inst(
    .clk             	(gmii_rxc 		),        
    .rst_n           	(rst_n       	),             
    .gmii_rxdv       	(gmii_rxdv  	),                                 
    .gmii_rxd        	(gmii_rxd    	),      
	.local_mac			(local_mac		),
	.local_ip			(local_ip		),
    .rxd_pkt_done      	(rxd_pkt_done	),      
    .rxd_wr_en          (rxd_wr_en      ),            
    .rxd_wr_data        (rxd_wr_data    ),          
    .rxd_wr_byte_num    (rxd_wr_byte_num)       
);                                    

//��̫������ģ��
udp_txd   udp_tx_inst(
    .clk             	(gmii_txc		),        
    .rst_n           	(rst_n      	),             
    .tx_start_en     	(tx_start_en	),                   
    .tx_data         	(tx_data    	),           
    .tx_byte_num     	(tx_byte_num	),    
    .destination_mac 	(destination_mac),
    .destination_ip     (destination_ip ), 
	.local_mac			(local_mac		),
	.local_ip			(local_ip		),	
    .crc_data        	(crc_data   	),          
    .crc_next        	(crc_next[31:24]),
    .tx_done         	(tx_done    	),           
    .tx_request         (tx_request     ),            
    .gmii_txen      	(gmii_txen 		),         
    .gmii_txd        	(gmii_txd   	),       
    .crc_en          	(crc_en     	),            
    .crc_clear         	(crc_clear    	)            
    );                                      

//ARP TXD module
crc32   crc32_inst(
    .clk             	(gmii_txc		),                      
    .rst_n           	(rst_n      	),                          
    .data_in        	(crc_d8     	),            
    .crc_en          	(crc_en     	),                          
    .crc_clear         	(crc_clear    	),                         
    .crc_data        	(crc_data   	),                        
    .crc_next        	(crc_next   	)                         
);

endmodule