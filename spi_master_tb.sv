

module spi_master_tb;

    parameter SPI_MODE = 0;
    parameter SPI_WIDTH_FRAME = 40;
    parameter DIV_FACTOR = 10;

    logic rst_n = 1'b0;
    wire  clk_ext;
    logic clk_enable = 1'b0;
    logic [SPI_WIDTH_FRAME-1:0] tx_frame_r = '0;
    logic start_r = 1'b0;
    logic busy_w;
    logic rx_valid_w;
    logic [SPI_WIDTH_FRAME-1:0] rx_frame_w;
    logic spi_sclk_w;
    logic spi_cs_n_w;
    logic spi_mosi_w;

    // Referência de 2 GHz (período de 500 ps).
    clock_gen #(.FREQ(2_000_000_000), .PHASE(0), .DUTY(50)) u_clock_gen (.enable(clk_enable), .clk(clk_ext));

    // Habilita o gerador após a inicialização, independentemente do reset.
    initial #1ps clk_enable = 1'b1;
    
    spi_master #( .SPI_MODE(SPI_MODE), .SPI_WIDTH_FRAME(SPI_WIDTH_FRAME), .DIV_FACTOR(DIV_FACTOR))
        UUT (
            .rst_n(rst_n), .clk(clk_ext), .tx_frame(tx_frame_r), .start(start_r), .busy(busy_w), 
            .rx_valid(rx_valid_w), .rx_frame(rx_frame_w), .spi_sclk(spi_sclk_w),
            .spi_cs_n(spi_cs_n_w), .spi_mosi(spi_mosi_w), .spi_miso(spi_mosi_w)
        );


    initial begin
`ifdef FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, spi_master_tb);
`endif

        repeat (10) @(negedge clk_ext);
        rst_n = 1'b1;

        send_frame(SPI_WIDTH_FRAME'(40'hC_1012_4567));
        repeat (10) @(negedge clk_ext);   // Pausa de 5 ns com clk_ext de 2 GHz.
        send_frame(SPI_WIDTH_FRAME'(40'hC_89AB_CDEF));

        repeat (10) @(negedge clk_ext);
        $finish;
    end

    initial begin
        #100_000;
        $fatal(1, "Timeout: a simulacao nao terminou.");
    end


    task automatic send_frame(input logic [SPI_WIDTH_FRAME-1:0] data);
        @(negedge clk_ext);
        while (busy_w) @(negedge clk_ext);
            tx_frame_r = data;
            start_r = 1'b1;
            @(negedge clk_ext);
            start_r = 1'b0;

            // Observa o resultado após as atualizações do mestre.
        do @(negedge clk_ext); while (!rx_valid_w);

        if (rx_frame_w !== data)
        $fatal(1, "Erro: enviado=%h recebido=%h", data, rx_frame_w);
        $display("PASS: enviado=%h recebido=%h", data, rx_frame_w);

    endtask


endmodule
