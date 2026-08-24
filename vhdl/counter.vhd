-------------------------------------------------------------------------------
-- counter.vhd (v2 - agrega modo automatico con prescaler)
--
-- Contador ascendente/descendente con resolucion configurable (por defecto
-- 4 bits, segun consigna). Casos borde:
--   - En el valor maximo, al incrementar vuelve a 0.
--   - En 0, al decrementar pasa al valor maximo.
-- El comando 'R' resetea el contador a 0 sin esperar al reset externo.
--
-- Modo automatico (feature extra):
--   - CMD_AUTO alterna (toggle) un modo donde el contador incrementa solo,
--     a un ritmo fijo definido por AUTO_TICK_DIVISOR (cantidad de ciclos de
--     clk entre cada auto-incremento).
--   - Cualquier comando manual (+, -, R) apaga el modo automatico y toma
--     control inmediato (prioridad sobre el auto-tick en el mismo ciclo).
--   - auto_mode se expone como salida para que el wrapper AXI pueda
--     informarlo por software (bit de estado en el registro de lectura).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    generic (
        COUNTER_WIDTH     : natural := 4;
        AUTO_TICK_DIVISOR : natural := 50_000_000  -- ~2 Hz a 100 MHz de clk
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;                                   -- reset sincrono, activo en alto
        cmd_valid : in  std_logic;                                   -- pulso: cmd valido
        cmd       : in  std_logic_vector(2 downto 0);                -- "001"=inc,"010"=dec,"011"=reset,"100"=auto-toggle
        count     : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
        auto_mode : out std_logic                                    -- '1' mientras el modo automatico esta activo
    );
end counter;

architecture rtl of counter is
    constant CMD_INC    : std_logic_vector(2 downto 0) := "001";
    constant CMD_DEC    : std_logic_vector(2 downto 0) := "010";
    constant CMD_RESET  : std_logic_vector(2 downto 0) := "011";
    constant CMD_AUTO   : std_logic_vector(2 downto 0) := "100";

    constant COUNT_MIN : unsigned(COUNTER_WIDTH-1 downto 0) := to_unsigned(0, COUNTER_WIDTH);
    constant COUNT_MAX : unsigned(COUNTER_WIDTH-1 downto 0) := to_unsigned((2**COUNTER_WIDTH)-1, COUNTER_WIDTH);

    signal count_i     : unsigned(COUNTER_WIDTH-1 downto 0);
    signal auto_mode_i : std_logic;
    signal tick_cnt     : unsigned(31 downto 0);
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count_i     <= COUNT_MIN;
                auto_mode_i <= '0';
                tick_cnt    <= (others => '0');
            elsif cmd_valid = '1' then
                -- un comando manual siempre tiene prioridad sobre el auto-tick
                case cmd is
                    when CMD_INC =>
                        auto_mode_i <= '0';
                        tick_cnt    <= (others => '0');
                        if count_i = COUNT_MAX then
                            count_i <= COUNT_MIN;          -- wrap-around: max -> 0
                        else
                            count_i <= count_i + 1;
                        end if;
                    when CMD_DEC =>
                        auto_mode_i <= '0';
                        tick_cnt    <= (others => '0');
                        if count_i = COUNT_MIN then
                            count_i <= COUNT_MAX;          -- wrap-around: 0 -> max
                        else
                            count_i <= count_i - 1;
                        end if;
                    when CMD_RESET =>
                        auto_mode_i <= '0';
                        tick_cnt    <= (others => '0');
                        count_i     <= COUNT_MIN;
                    when CMD_AUTO =>
                        auto_mode_i <= not auto_mode_i;    -- toggle on/off
                        tick_cnt    <= (others => '0');    -- arrancar el prescaler de cero
                    when others =>
                        null;                              -- no deberia ocurrir
                end case;
            elsif auto_mode_i = '1' then
                -- modo automatico: incrementar cada AUTO_TICK_DIVISOR ciclos
                if tick_cnt = to_unsigned(AUTO_TICK_DIVISOR - 1, tick_cnt'length) then
                    tick_cnt <= (others => '0');
                    if count_i = COUNT_MAX then
                        count_i <= COUNT_MIN;
                    else
                        count_i <= count_i + 1;
                    end if;
                else
                    tick_cnt <= tick_cnt + 1;
                end if;
            else
                tick_cnt <= (others => '0');
            end if;
        end if;
    end process;

    count     <= std_logic_vector(count_i);
    auto_mode <= auto_mode_i;

end rtl;