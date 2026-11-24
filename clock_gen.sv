

module clock_gen #(parameter FREQ = 500_000, PHASE = 0, DUTY = 50)( // Hz, graus, %.
    input wire enable,
    output reg clk
);

localparam CLK_PERIOD = 1e9/FREQ; // Período em ns.
localparam CLK_ON_TIME = DUTY/100.0*CLK_PERIOD;
localparam CLK_OFF_TIME = (100.0-DUTY)/100.0*CLK_PERIOD;
localparam CLK_START_DELAY = CLK_PERIOD*PHASE/360.0; // Atraso de fase em ns.

reg start_clk; // Habilitação interna com atraso de fase.

// Inicializa as variáveis em zero.
initial begin
    clk <= 1'b0;
    start_clk <= 1'b0;
end

// Captura enable no evento e aplica o valor após o atraso de fase.
always @(posedge enable or negedge enable) begin
    start_clk = #(CLK_START_DELAY) (enable === 1'b1);
end

always @(posedge start_clk) begin
    clk = 1'b1;

    while (start_clk) begin
        #(CLK_ON_TIME) clk = 1'b0;
        #(CLK_OFF_TIME) clk = 1'b1;
    end

    clk = 1'b0;
end

endmodule