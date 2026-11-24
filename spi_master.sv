
module spi_master
  #(parameter SPI_MODE = 0, parameter SPI_WIDTH_FRAME = 40, parameter DIV_FACTOR = 10)
  (
  input                              rst_n,     // Reset global assíncrono, ativo em zero.
  input                              clk,       // Global Clock
  
  // TX (MOSI) Signals
  input  logic [SPI_WIDTH_FRAME-1:0] tx_frame, // Frame a transmitir por MOSI, MSB-first.
  input  logic                       start,    // Solicita transmissão e recepção de um frame quando busy=0.
  output logic                       busy,     // Mestre ocupado ou em reset.

  // RX (MISO) Signalss
  output logic                       rx_valid, // Pulso de um ciclo de clk: rx_frame disponível.
  output logic [SPI_WIDTH_FRAME-1:0] rx_frame, // Último frame recebido por MISO.

   // SPI Interface
  output logic                       spi_sclk, // freq(spi_sclk) = freq(clk)/DIV_FACTOR; para freq(clk) = 250MHz e DIV_FACTOR = 10, freq(spi_sclk) = 25 MHz.
  output logic                       spi_cs_n,
  output logic                       spi_mosi,
  input  logic                       spi_miso
);
 
  localparam bit CPOL = SPI_MODE[1];
  localparam bit CPHA = SPI_MODE[0];

  typedef enum logic [1:0] {ST_IDLE, ST_SETUP, ST_TRANSFER, ST_FINISH} state_t;
  state_t state_q;

  logic [$clog2(DIV_FACTOR)-1:0] clk_count_q;
  logic [$clog2(SPI_WIDTH_FRAME+1)-1:0] bit_count;
  logic [SPI_WIDTH_FRAME-1:0] tx_frame_q, rx_shift_q;

  assign busy = !rst_n || (state_q != ST_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin : SPI_FSM_LOGIC
      if (!rst_n) begin
          state_q <= ST_IDLE;
          spi_sclk <= CPOL;
          spi_cs_n <= 1'b1;
          spi_mosi <= 1'b0;
          rx_valid <= 1'b0;
          rx_frame <= '0;
          clk_count_q <= '0;
          bit_count <= '0;
          tx_frame_q <= '0;
          rx_shift_q <= '0;
      end else begin
          rx_valid <= 1'b0;

          case (state_q)
              ST_IDLE: begin
                  spi_sclk <= CPOL;
                  spi_cs_n <= 1'b1;
                  clk_count_q <= '0;
                  bit_count <= '0;

                  if (start) begin
                      tx_frame_q <= tx_frame;
                      rx_shift_q <= '0;
                      state_q <= ST_SETUP;
                  end
              end

              ST_SETUP: begin
                  spi_cs_n <= 1'b0;
                  clk_count_q <= '0;

                  if (!CPHA) begin // o bit já é apresentado para spi_mosi, pois deve ser amostrado na primeria borda
                      spi_mosi <= tx_frame_q[SPI_WIDTH_FRAME-1];
                      tx_frame_q <= tx_frame_q << 1;
                  end else begin
                      spi_mosi <= 1'b0; // CPHA=1: o primeiro bit será apresentado na primeira borda de SCLK.
                  end

                  state_q <= ST_TRANSFER;
              end

              ST_TRANSFER: begin
                  if (clk_count_q == (DIV_FACTOR/2)-1) begin
                      clk_count_q <= '0;
                      spi_sclk <= ~spi_sclk;

                      case (SPI_MODE)
                        2'd0: begin // CPOL=0, CPHA=0.
                          if(!spi_sclk) begin // borda: positiva.
                            rx_shift_q <= (rx_shift_q << 1) | SPI_WIDTH_FRAME'(spi_miso); // amostra de miso
                          end else begin // borda: negativa
                            spi_mosi <= tx_frame_q[SPI_WIDTH_FRAME-1]; // desloca para mosi
                            tx_frame_q <= tx_frame_q << 1;
                          end
                        end
                        2'd1: begin
                          if(!spi_sclk) begin // borda: positiva
                            spi_mosi <= tx_frame_q[SPI_WIDTH_FRAME-1]; // desloca para mosi
                            tx_frame_q <= tx_frame_q << 1;
                          end else begin // borda: negativa
                            rx_shift_q <= (rx_shift_q << 1) | SPI_WIDTH_FRAME'(spi_miso); // amostra de miso
                          end
                        end
                        2'd2: begin // CPOL=1, CPHA=0.
                            if (spi_sclk) begin // borda: negativa
                                rx_shift_q <= (rx_shift_q << 1) | SPI_WIDTH_FRAME'(spi_miso);  // amostra de miso
                            end else begin // borda: positiva
                                spi_mosi <= tx_frame_q[SPI_WIDTH_FRAME-1]; // desloca para mosi
                                tx_frame_q <= tx_frame_q << 1;
                            end
                        end
                        2'd3: begin // CPOL=1, CPHA=1.
                            if (spi_sclk) begin // borda: negativa
                                spi_mosi <= tx_frame_q[SPI_WIDTH_FRAME-1]; // desloca para mosi
                                tx_frame_q <= tx_frame_q << 1;
                            end else begin // borda: positiva
                                rx_shift_q <= (rx_shift_q << 1) | SPI_WIDTH_FRAME'(spi_miso); // amostra de miso
                            end
                        end
                        default: begin end
                      endcase

                  // Conta um bit apenas quando SCLK completa um ciclo, ou seja, quando spi_sclk != CPOL
                  if (spi_sclk != CPOL) begin
                      if (bit_count == SPI_WIDTH_FRAME-1) // termina exatamente SPI_WIDTH_FRAME ciclos de SCLK
                          state_q <= ST_FINISH;
                      else
                          bit_count <= bit_count + 1'b1;
                  end

                  end else begin // conta por meio ciclo
                      clk_count_q <= clk_count_q + 1'b1;
                  end
              end

              ST_FINISH: begin
                  spi_sclk <= CPOL;
                  spi_cs_n <= 1'b1;
                  rx_frame <= rx_shift_q;
                  rx_valid <= 1'b1;
                  state_q <= ST_IDLE;
              end

              default: begin
                  spi_sclk <= CPOL;
                  spi_cs_n <= 1'b1;
                  clk_count_q <= '0;
                  bit_count <= '0;
                  state_q <= ST_IDLE;
              end
          endcase
      end
  end



endmodule