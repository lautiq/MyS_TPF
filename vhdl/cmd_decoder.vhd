-------------------------------------------------------------------------------
-- cmd_decoder.vhd (v2 - agrego comando de modo automatico)
--
-- Decodifica un byte ASCII recibido (data_in) en un comando de 3 bits para
-- el contador. Se asume que data_valid es un pulso de un ciclo indicando que
-- hay un byte nuevo disponible (en el TPF, este pulso viene de slv_reg_wren
-- del wrapper AXI-Lite).
--
-- Comandos soportados:
--   '+' (0x2B)      -> cmd = "001"  (incrementar, apaga modo auto si estaba activo)
--   '-' (0x2D)      -> cmd = "010"  (decrementar, apaga modo auto si estaba activo)
--   'R'/'r'         -> cmd = "011"  (reset, apaga modo auto si estaba activo)
--   'A'/'a'         -> cmd = "100"  (alterna modo automatico on/off)
--   cualquier otro caracter -> no se genera cmd_valid (no accion)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity cmd_decoder is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;                     -- reset sincrono, activo en alto
        data_in    : in  std_logic_vector(7 downto 0);   -- byte ASCII recibido
        data_valid : in  std_logic;                      -- pulso: hay byte nuevo
        cmd        : out std_logic_vector(2 downto 0);   -- comando decodificado
        cmd_valid  : out std_logic                       -- pulso: cmd valido para el counter
    );
end cmd_decoder;

architecture rtl of cmd_decoder is
    constant CHAR_PLUS  : std_logic_vector(7 downto 0) := x"2B"; -- '+'
    constant CHAR_MINUS : std_logic_vector(7 downto 0) := x"2D"; -- '-'
    constant CHAR_R_UP  : std_logic_vector(7 downto 0) := x"52"; -- 'R'
    constant CHAR_R_LOW : std_logic_vector(7 downto 0) := x"72"; -- 'r'
    constant CHAR_A_UP  : std_logic_vector(7 downto 0) := x"41"; -- 'A'
    constant CHAR_A_LOW : std_logic_vector(7 downto 0) := x"61"; -- 'a'

    constant CMD_INC    : std_logic_vector(2 downto 0) := "001";
    constant CMD_DEC    : std_logic_vector(2 downto 0) := "010";
    constant CMD_RESET  : std_logic_vector(2 downto 0) := "011";
    constant CMD_AUTO   : std_logic_vector(2 downto 0) := "100";
    constant CMD_NONE   : std_logic_vector(2 downto 0) := "000";
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cmd       <= CMD_NONE;
                cmd_valid <= '0';
            elsif data_valid = '1' then
                case data_in is
                    when CHAR_PLUS =>
                        cmd       <= CMD_INC;
                        cmd_valid <= '1';
                    when CHAR_MINUS =>
                        cmd       <= CMD_DEC;
                        cmd_valid <= '1';
                    when CHAR_R_UP | CHAR_R_LOW =>
                        cmd       <= CMD_RESET;
                        cmd_valid <= '1';
                    when CHAR_A_UP | CHAR_A_LOW =>
                        cmd       <= CMD_AUTO;
                        cmd_valid <= '1';
                    when others =>
                        -- caracter invalido: no se realiza ninguna accion
                        cmd       <= CMD_NONE;
                        cmd_valid <= '0';
                end case;
            else
                -- cmd_valid es un pulso de un solo ciclo
                cmd_valid <= '0';
            end if;
        end if;
    end process;

end rtl;