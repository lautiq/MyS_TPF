-------------------------------------------------------------------------------
-- tb_cmd_counter_ip_v1_0_S_AXI.vhd
--
-- Testbench que actua como maestro AXI4-Lite: escribe comandos en el
-- registro 0x0 y lee el registro 0x4 para verificar el valor del contador.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cmd_counter_ip_v1_0_S_AXI is
end tb_cmd_counter_ip_v1_0_S_AXI;

architecture sim of tb_cmd_counter_ip_v1_0_S_AXI is

    constant CLK_PERIOD : time := 10 ns;
    constant C_S_AXI_DATA_WIDTH : integer := 32;
    constant C_S_AXI_ADDR_WIDTH : integer := 4;

    signal S_AXI_ACLK    : std_logic := '0';
    signal S_AXI_ARESETN : std_logic := '0';

    signal S_AXI_AWADDR  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal S_AXI_AWPROT  : std_logic_vector(2 downto 0) := (others => '0');
    signal S_AXI_AWVALID : std_logic := '0';
    signal S_AXI_AWREADY : std_logic;

    signal S_AXI_WDATA   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
    signal S_AXI_WSTRB   : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0) := (others => '1');
    signal S_AXI_WVALID  : std_logic := '0';
    signal S_AXI_WREADY  : std_logic;

    signal S_AXI_BRESP   : std_logic_vector(1 downto 0);
    signal S_AXI_BVALID  : std_logic;
    signal S_AXI_BREADY  : std_logic := '0';

    signal S_AXI_ARADDR  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal S_AXI_ARPROT  : std_logic_vector(2 downto 0) := (others => '0');
    signal S_AXI_ARVALID : std_logic := '0';
    signal S_AXI_ARREADY : std_logic;

    signal S_AXI_RDATA   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal S_AXI_RRESP   : std_logic_vector(1 downto 0);
    signal S_AXI_RVALID  : std_logic;
    signal S_AXI_RREADY  : std_logic := '0';

    -- Escribe una palabra de 32 bits en la direccion "addr" (transaccion AXI4-Lite completa).
    -- BREADY/RREADY se dejan en '1' de forma permanente (ver stim_proc), asi que alcanza con
    -- pulsar AWVALID/WVALID un par de ciclos y darle tiempo al wrapper a completar el handshake
    -- (usar tiempo fijo en vez de "wait until señal_derivada" evita el desfase de un delta que
    -- provoca deadlocks al sincronizar con señales que dependen a su vez del mismo flanco de clk).
    procedure axi_write(
        signal   awaddr_s  : out std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        signal   awvalid_s : out std_logic;
        signal   wdata_s   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        signal   wvalid_s  : out std_logic;
        constant addr      : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        constant data      : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0)
    ) is
    begin
        wait until rising_edge(S_AXI_ACLK);
        awaddr_s  <= addr;
        awvalid_s <= '1';
        wdata_s   <= data;
        wvalid_s  <= '1';

        -- mantener VALID un ciclo extra: AWREADY/WREADY recien aparecen en el
        -- flanco siguiente, y deben coincidir con VALID=1 en el MISMO flanco
        -- para que el wrapper genere el pulso de escritura (slv_reg_wren).
        wait until rising_edge(S_AXI_ACLK);
        wait until rising_edge(S_AXI_ACLK);
        awvalid_s <= '0';
        wvalid_s  <= '0';

        -- dar tiempo a que el wrapper complete AW/W -> B (unos ciclos de sobra)
        wait for CLK_PERIOD*4;
    end procedure;

    -- Lee una palabra de 32 bits desde la direccion "addr"
    procedure axi_read(
        signal   araddr_s  : out std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        signal   arvalid_s : out std_logic;
        signal   rdata_s   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        constant addr      : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        variable data_out  : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0)
    ) is
    begin
        wait until rising_edge(S_AXI_ACLK);
        araddr_s  <= addr;
        arvalid_s <= '1';

        wait until rising_edge(S_AXI_ACLK);
        wait until rising_edge(S_AXI_ACLK);
        arvalid_s <= '0';

        -- dar tiempo a que el wrapper complete AR -> R y muestrear
        wait for CLK_PERIOD*4;
        data_out := rdata_s;
    end procedure;

begin

    UUT: entity work.cmd_counter_ip_v1_0_S_AXI
        generic map (
            COUNTER_WIDTH      => 4,
            AUTO_TICK_DIVISOR  => 5,  -- chico a proposito, solo para simular rapido
            C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
        )
        port map (
            S_AXI_ACLK    => S_AXI_ACLK,
            S_AXI_ARESETN => S_AXI_ARESETN,
            S_AXI_AWADDR  => S_AXI_AWADDR,
            S_AXI_AWPROT  => S_AXI_AWPROT,
            S_AXI_AWVALID => S_AXI_AWVALID,
            S_AXI_AWREADY => S_AXI_AWREADY,
            S_AXI_WDATA   => S_AXI_WDATA,
            S_AXI_WSTRB   => S_AXI_WSTRB,
            S_AXI_WVALID  => S_AXI_WVALID,
            S_AXI_WREADY  => S_AXI_WREADY,
            S_AXI_BRESP   => S_AXI_BRESP,
            S_AXI_BVALID  => S_AXI_BVALID,
            S_AXI_BREADY  => S_AXI_BREADY,
            S_AXI_ARADDR  => S_AXI_ARADDR,
            S_AXI_ARPROT  => S_AXI_ARPROT,
            S_AXI_ARVALID => S_AXI_ARVALID,
            S_AXI_ARREADY => S_AXI_ARREADY,
            S_AXI_RDATA   => S_AXI_RDATA,
            S_AXI_RRESP   => S_AXI_RRESP,
            S_AXI_RVALID  => S_AXI_RVALID,
            S_AXI_RREADY  => S_AXI_RREADY
        );

    S_AXI_ACLK <= not S_AXI_ACLK after CLK_PERIOD/2;

    stim_proc: process
        variable rdata : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    begin
        -- BREADY/RREADY quedan en alto todo el tiempo: simplifica el maestro simulado,
        -- el wrapper ya maneja el resto del handshake por su cuenta.
        S_AXI_BREADY <= '1';
        S_AXI_RREADY <= '1';

        -- reset
        S_AXI_ARESETN <= '0';
        wait for CLK_PERIOD*4;
        S_AXI_ARESETN <= '1';
        wait for CLK_PERIOD*2;

        -- escribir '+' tres veces en el registro de comando (0x0)
        axi_write(S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WVALID, x"0", x"0000002B");
        axi_write(S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WVALID, x"0", x"0000002B");
        axi_write(S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WVALID, x"0", x"0000002B");

        -- leer el registro de contador (0x4), se espera 3
        axi_read(S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_RDATA, x"4", rdata);
        assert rdata(3 downto 0) = "0011"
            report "FALLO: se esperaba count=3 via AXI" severity error;

        -- escribir '-' una vez
        axi_write(S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WVALID, x"0", x"0000002D");
        axi_read(S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_RDATA, x"4", rdata);
        assert rdata(3 downto 0) = "0010"
            report "FALLO: se esperaba count=2 via AXI" severity error;

        -- escribir 'R' (reset)
        axi_write(S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WVALID, x"0", x"00000052");
        axi_read(S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_RDATA, x"4", rdata);
        assert rdata(3 downto 0) = "0000"
            report "FALLO: se esperaba count=0 tras R via AXI" severity error;

        -- decrementar desde 0: wrap-around a 15
        axi_write(S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WVALID, x"0", x"0000002D");
        axi_read(S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_RDATA, x"4", rdata);
        assert rdata(3 downto 0) = "1111"
            report "FALLO: se esperaba wrap-around a 15 via AXI" severity error;

        -- activar modo automatico ('A') via AXI y verificar bit de estado + auto-incremento
        axi_write(S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WVALID, x"0", x"00000041"); -- 'A'
        wait for CLK_PERIOD*10; -- unos cuantos ticks del prescaler chico (divisor=5)

        axi_read(S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_RDATA, x"4", rdata);
        assert rdata(4) = '1'
            report "FALLO: se esperaba bit de auto_mode=1 via AXI" severity error;
        assert unsigned(rdata(3 downto 0)) > 0
            report "FALLO: se esperaba que el contador ya hubiera auto-incrementado" severity error;

        -- un comando manual ('+') debe apagar el modo automatico
        axi_write(S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_WDATA, S_AXI_WVALID, x"0", x"0000002B"); -- '+'
        axi_read(S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_RDATA, x"4", rdata);
        assert rdata(4) = '0'
            report "FALLO: el '+' manual deberia apagar el modo automatico (bit 4)" severity error;

        report "Testbench AXI finalizado sin errores (si no se vieron asserts de FALLO arriba).";
        wait;
    end process;

end sim;