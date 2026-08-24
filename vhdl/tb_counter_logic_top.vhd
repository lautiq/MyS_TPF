-------------------------------------------------------------------------------
-- tb_counter_logic_top.vhd
--
-- Testbench del bloque counter_logic_top (cmd_decoder + counter), sin AXI.
-- Casos cubiertos:
--   1) Incrementar 3 veces ('+','+','+')       -> count = 3
--   2) Decrementar 1 vez ('-')                 -> count = 2
--   3) Caracter invalido ('Z')                 -> count no cambia
--   4) Comando reset ('R')                     -> count = 0
--   5) Decrementar desde 0 (wrap-around)       -> count = 15 (max)
--   6) Incrementar desde el maximo (wrap-around) -> count = 0
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_counter_logic_top is
end tb_counter_logic_top;

architecture sim of tb_counter_logic_top is

    constant COUNTER_WIDTH : natural := 4;
    constant CLK_PERIOD    : time := 10 ns;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal count      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal auto_mode  : std_logic;
    constant AUTO_TICK_DIVISOR_SIM : natural := 5; -- chico a proposito, solo para simular rapido

    -- Envia un byte durante un ciclo de clock (simula una escritura AXI)
    procedure send_char(
        signal   data_in_s    : out std_logic_vector(7 downto 0);
        signal   data_valid_s : out std_logic;
        constant char_code    : in  std_logic_vector(7 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        data_in_s    <= char_code;
        data_valid_s <= '1';
        wait until rising_edge(clk);
        data_valid_s <= '0';
    end procedure;

begin

    UUT: entity work.counter_logic_top
        generic map (
            COUNTER_WIDTH     => COUNTER_WIDTH,
            AUTO_TICK_DIVISOR => AUTO_TICK_DIVISOR_SIM
        )
        port map (
            clk        => clk,
            rst        => rst,
            data_in    => data_in,
            data_valid => data_valid,
            count      => count,
            auto_mode  => auto_mode
        );

    clk <= not clk after CLK_PERIOD/2;

    stim_proc: process
    begin
        -- reset inicial
        rst <= '1';
        wait for CLK_PERIOD*2;
        rst <= '0';
        wait for CLK_PERIOD*2;

        -- 1) incrementar 3 veces: 0 -> 1 -> 2 -> 3
        send_char(data_in, data_valid, x"2B"); -- '+'
        send_char(data_in, data_valid, x"2B");
        send_char(data_in, data_valid, x"2B");
        wait for CLK_PERIOD*2;
        assert count = "0011"
            report "FALLO: se esperaba count=3 tras 3 incrementos" severity error;

        -- 2) decrementar 1 vez: 3 -> 2
        send_char(data_in, data_valid, x"2D"); -- '-'
        wait for CLK_PERIOD*2;
        assert count = "0010"
            report "FALLO: se esperaba count=2 tras un decremento" severity error;

        -- 3) caracter invalido: no debe cambiar
        send_char(data_in, data_valid, x"5A"); -- 'Z'
        wait for CLK_PERIOD*2;
        assert count = "0010"
            report "FALLO: un comando invalido no deberia modificar el contador" severity error;

        -- 4) comando reset 'R'
        send_char(data_in, data_valid, x"52"); -- 'R'
        wait for CLK_PERIOD*2;
        assert count = "0000"
            report "FALLO: se esperaba count=0 tras el comando R" severity error;

        -- 5) decrementar desde 0 -> wrap-around al maximo (15)
        send_char(data_in, data_valid, x"2D"); -- '-'
        wait for CLK_PERIOD*2;
        assert count = "1111"
            report "FALLO: se esperaba wrap-around a 15 al decrementar desde 0" severity error;

        -- 6) incrementar desde el maximo -> wrap-around a 0
        send_char(data_in, data_valid, x"2B"); -- '+'
        wait for CLK_PERIOD*2;
        assert count = "0000"
            report "FALLO: se esperaba wrap-around a 0 al incrementar desde el maximo" severity error;

        -- 7) activar modo automatico ('A') y verificar que el contador
        --    incrementa solo, cada AUTO_TICK_DIVISOR_SIM ciclos
        send_char(data_in, data_valid, x"41"); -- 'A'
        wait for CLK_PERIOD * (AUTO_TICK_DIVISOR_SIM + 2);
        assert auto_mode = '1'
            report "FALLO: se esperaba auto_mode=1 tras el comando A" severity error;
        assert count = "0001"
            report "FALLO: se esperaba un auto-incremento (count=1)" severity error;

        wait for CLK_PERIOD * (AUTO_TICK_DIVISOR_SIM + 1);
        assert count = "0010"
            report "FALLO: se esperaba un segundo auto-incremento (count=2)" severity error;

        -- 8) un comando manual ('+') debe apagar el modo automatico
        send_char(data_in, data_valid, x"2B"); -- '+'
        wait for CLK_PERIOD*2;
        assert auto_mode = '0'
            report "FALLO: un comando manual deberia apagar el modo automatico" severity error;
        assert count = "0011"
            report "FALLO: se esperaba count=3 tras el '+' manual" severity error;

        -- esperar varios ciclos mas: el contador NO debe seguir incrementando solo
        wait for CLK_PERIOD * (AUTO_TICK_DIVISOR_SIM * 2);
        assert count = "0011"
            report "FALLO: el contador no deberia incrementar solo con auto_mode apagado" severity error;

        report "Testbench finalizado sin errores (si no se vieron asserts de FALLO arriba).";
        wait;
    end process;

end sim;