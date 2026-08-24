-------------------------------------------------------------------------------
-- counter_logic_top.vhd (v2 - agrego modo automatico)
--
-- Une cmd_decoder + counter. Este bloque es el que se instancia dentro del
-- wrapper AXI-Lite (data_in <= S_AXI_WDATA(7 downto 0),
-- data_valid <= slv_reg_wren, count/auto_mode se exponen en el registro
-- de lectura).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity counter_logic_top is
    generic (
        COUNTER_WIDTH     : natural := 4;
        AUTO_TICK_DIVISOR : natural := 50_000_000
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        data_in    : in  std_logic_vector(7 downto 0);
        data_valid : in  std_logic;
        count      : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
        auto_mode  : out std_logic
    );
end counter_logic_top;

architecture struct of counter_logic_top is

    signal cmd_i       : std_logic_vector(2 downto 0);
    signal cmd_valid_i : std_logic;

begin

    U_CMD_DECODER: entity work.cmd_decoder
        port map (
            clk        => clk,
            rst        => rst,
            data_in    => data_in,
            data_valid => data_valid,
            cmd        => cmd_i,
            cmd_valid  => cmd_valid_i
        );

    U_COUNTER: entity work.counter
        generic map (
            COUNTER_WIDTH     => COUNTER_WIDTH,
            AUTO_TICK_DIVISOR => AUTO_TICK_DIVISOR
        )
        port map (
            clk       => clk,
            rst       => rst,
            cmd_valid => cmd_valid_i,
            cmd       => cmd_i,
            count     => count,
            auto_mode => auto_mode
        );

end struct;