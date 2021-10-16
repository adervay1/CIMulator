module prime_cyclone_iv_top (
    input           sys_clk_in,
    output [7:0]    leds_out,
    output [12:0]   sdram_addr_out,
    output [1:0]    sdram_ba_out,
    output          sdram_cas_n_out,
    output          sdram_cke_out,
    output          sdram_cs_n_out,
    inout [15:0]    sdram_dq_io,
    output [1:0]    sdram_dqm_out,
    output          sdram_ras_n_out,
    output          sdram_we_n_out,
    output          sdram_clk_out
    
);



wire          avalon_mm_waitrequest;
wire [31:0]   avalon_mm_readdata;
wire          avalon_mm_readdatavalid;

wire [31:0]    avalon_mm_writedata;
wire [8:0]     avalon_mm_address;
wire           avalon_mm_write;
wire           avalon_mm_read;



wire          avalon_mm_prom_waitrequest;
wire [31:0]   avalon_mm_prom_readdata;
wire          avalon_mm_prom_readdatavalid;

wire [31:0]    avalon_mm_prom_writedata;
wire [3:0]     avalon_mm_prom_address;
wire           avalon_mm_prom_write;
wire           avalon_mm_prom_read;



wire          avalon_mm_2_waitrequest;
wire [31:0]   avalon_mm_2_readdata;
wire          avalon_mm_2_readdatavalid;

wire [31:0]    avalon_mm_2_writedata;
wire [8:0]     avalon_mm_2_address;
wire           avalon_mm_2_write;
wire           avalon_mm_2_read;

wire            st_clk_100mhz;

wire            advance_instruction;
wire            start_prom_execution;
wire [31:0]     current_instruction;

wire            program_complete_irq;


clk_skew_pll pll_u0 (
    .inclk0 (sys_clk_in),
    .c0     (sdram_clk_out),
    .c1     (st_clk_100mhz)
);




NIOS_Top nios_u0 (
    .clk_clk                            (sys_clk_in), // clk.clk
    .reset_reset_n                      (1'b1), // reset.reset_n
    //.irq_bridge_0_receiver_irq_irq      (program_complete_irq),
    .pio_irq_export                     (program_complete_irq),
    .led_pio_external_connection_export (leds_out), // led_pio_external_connection.export
    .sdram_wire_addr                    (sdram_addr_out), // sdram_wire.addr
    .sdram_wire_ba                      (sdram_ba_out), // .ba
    .sdram_wire_cas_n                   (sdram_cas_n_out), // .cas_n
    .sdram_wire_cke                     (sdram_cke_out), // .cke
    .sdram_wire_cs_n                    (sdram_cs_n_out), // .cs_n
    .sdram_wire_dq                      (sdram_dq_io), // .dq
    .sdram_wire_dqm                     (sdram_dqm_out), // .dqm
    .sdram_wire_ras_n                   (sdram_ras_n_out), // .ras_n
    .sdram_wire_we_n                    (sdram_we_n_out), // .we_n
    
    .mm_bridge_master_waitrequest       (avalon_mm_waitrequest), // mm_bridge_master.waitrequest
    .mm_bridge_master_readdata          (avalon_mm_readdata), // .readdata
    .mm_bridge_master_readdatavalid     (avalon_mm_readdatavalid), // .readdatavalid
    .mm_bridge_master_burstcount        (), // .burstcount
    .mm_bridge_master_writedata         (avalon_mm_writedata), // .writedata
    .mm_bridge_master_address           (avalon_mm_address), // .address
    .mm_bridge_master_write             (avalon_mm_write), // .write
    .mm_bridge_master_read              (avalon_mm_read), // .read
    .mm_bridge_master_byteenable        (), // .byteenable
    .mm_bridge_master_debugaccess       (), // .debugaccess
    
    
    .mm_bridge_master_prom_waitrequest      (avalon_mm_prom_waitrequest), // mm_bridge_master_prom.waitrequest
    .mm_bridge_master_prom_readdata         (avalon_mm_prom_readdata), // .readdata
    .mm_bridge_master_prom_readdatavalid    (avalon_mm_prom_readdatavalid), // .readdatavalid
    .mm_bridge_master_prom_burstcount       (), // .burstcount
    .mm_bridge_master_prom_writedata        (avalon_mm_prom_writedata), // .writedata
    .mm_bridge_master_prom_address          (avalon_mm_prom_address), // .address
    .mm_bridge_master_prom_write            (avalon_mm_prom_write), // .write
    .mm_bridge_master_prom_read             (avalon_mm_prom_read), // .read
    .mm_bridge_master_prom_byteenable       (), // .byteenable
    .mm_bridge_master_prom_debugaccess      (), // .debugaccess
     
     .mm_bridge_master_2_waitrequest       (avalon_mm_2_waitrequest), // mm_bridge_master.waitrequest
    .mm_bridge_master_2_readdata          (avalon_mm_2_readdata), // .readdata
    .mm_bridge_master_2_readdatavalid     (avalon_mm_2_readdatavalid), // .readdatavalid
    .mm_bridge_master_2_burstcount        (), // .burstcount
    .mm_bridge_master_2_writedata         (avalon_mm_2_writedata), // .writedata
    .mm_bridge_master_2_address           (avalon_mm_2_address), // .address
    .mm_bridge_master_2_write             (avalon_mm_2_write), // .write
    .mm_bridge_master_2_read              (avalon_mm_2_read), // .read
    .mm_bridge_master_2_byteenable        (), // .byteenable
    .mm_bridge_master_2_debugaccess       () // .debugaccess
);

/*
avalon_mm_translator avalon_mm_translator_inst  (
    .avalon_clk_in                      (sys_clk_in),
    .avalon_rst_n_in                    (1'b1),

    .avalon_mm_waitrequest_out      (avalon_mm_waitrequest),
    .avalon_mm_readdata_out         (avalon_mm_readdata),
    .avalon_mm_readdatavalid_out    (avalon_mm_readdatavalid),

    .avalon_mm_burstcount_in        (), // Unused
    .avalon_mm_writedata_in         (avalon_mm_writedata),
    .avalon_mm_address_in           (avalon_mm_address),
    .avalon_mm_write_in             (avalon_mm_write),
    .avalon_mm_read_in              (avalon_mm_read),
    .avalon_mm_byteenable_in        ()  // Unused
    
);
*/

prime_datapath_prom #(
    .INSTRUCTION_WIDTH(32),
    .PC_WIDTH(10),
    .PROM_CONTROL_ADDR_BITS(4)
)
prime_datapath_prom_inst (
    .sys_clk_in                     (sys_clk_in),
    .sys_reset_in                   (1'b0),

    //IMC Main Master
    .IMC_mm_waitrequest_out     (avalon_mm_waitrequest),
    .IMC_mm_readdata_out        (avalon_mm_readdata),
    .IMC_mm_readdatavalid_out   (avalon_mm_readdatavalid),

    .IMC_mm_writedata_in        (avalon_mm_writedata),
    .IMC_mm_address_in          (avalon_mm_address),
    .IMC_mm_write_in            (avalon_mm_write),
    .IMC_mm_read_in             (avalon_mm_read),
    
    //PROM Control Bus
    .PROM_mm_waitrequest_out    (avalon_mm_prom_waitrequest),
    .PROM_mm_readdata_out       (avalon_mm_prom_readdata),
    .PROM_mm_readdatavalid_out  (avalon_mm_prom_readdatavalid),

    .PROM_mm_writedata_in       (avalon_mm_prom_writedata),
    .PROM_mm_address_in         (avalon_mm_prom_address),
    .PROM_mm_write_in           (avalon_mm_prom_write),
    .PROM_mm_read_in            (avalon_mm_prom_read),
    
    .PROM_irq_out               (program_complete_irq)
);


prime_datapath prime_datapath_inst (
    .sys_clk_in                 (sys_clk_in),
    .sys_reset_in               (1'b0),

    //IMC Main Master
    .IMC_mm_waitrequest_out     (avalon_mm_2_waitrequest),
    .IMC_mm_readdata_out        (avalon_mm_2_readdata),
    .IMC_mm_readdatavalid_out   (avalon_mm_2_readdatavalid),

    .IMC_mm_writedata_in        (avalon_mm_2_writedata),
    .IMC_mm_address_in          (avalon_mm_2_address),
    .IMC_mm_write_in            (avalon_mm_2_write),
    .IMC_mm_read_in             (avalon_mm_2_read)
);


endmodule