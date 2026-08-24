-------------------------------------------------------------------------------
-- cmd_counter_ip_v1_0_S_AXI.vhd
--
-- Wrapper AXI4-Lite para el IP del contador ascendente/descendente.
-- Mapa de registros (offsets de 32 bits, palabra completa):
--   0x0 (CMD_REG)   - escritura: byte ASCII del comando en WDATA[7:0]
--                      ('+','-','R'/'r'). Cada escritura valida dispara
--                      un pulso hacia counter_logic_top.
--   0x4 (COUNT_REG) - lectura: valor actual del contador en RDATA[COUNTER_WIDTH-1:0]
--
-- El protocolo AXI4-Lite (canales AW/W/B/AR/R) es el patron estandar de
-- Vivado (identico al usado en led_ip_v1_0_S_AXI.vhd de lab3), sin
-- modificaciones. Lo unico custom es la seccion de registros de usuario.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmd_counter_ip_v1_0_S_AXI is
	generic (
		-- Users to add parameters here
		COUNTER_WIDTH	: natural	:= 4;
		AUTO_TICK_DIVISOR : natural := 50_000_000;  -- ~2 Hz a 100 MHz de clk (modo automatico)
		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Width of S_AXI data bus
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		-- Width of S_AXI address bus
		C_S_AXI_ADDR_WIDTH	: integer	:= 4
	);
	port (
		-- Global Clock Signal
		S_AXI_ACLK	: in std_logic;
		-- Global Reset Signal. This Signal is Active LOW
		S_AXI_ARESETN	: in std_logic;
		-- Write address (issued by master, acceped by Slave)
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
	);
end cmd_counter_ip_v1_0_S_AXI;

architecture arch_imp of cmd_counter_ip_v1_0_S_AXI is

	-- AXI4LITE signals (boilerplate estandar, sin modificar)
	signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	constant ADDR_LSB  : integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS : integer := 1;

	signal slv_reg_rden	: std_logic;
	signal slv_reg_wren	: std_logic;
	signal reg_data_out	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal aw_en	: std_logic;

	-- Registro map (offsets de palabra, "00" = 0x0, "01" = 0x4)
	constant REG_CMD_ADDR   : std_logic_vector(OPT_MEM_ADDR_BITS downto 0) := b"00";
	constant REG_COUNT_ADDR : std_logic_vector(OPT_MEM_ADDR_BITS downto 0) := b"01";

	-- Señales especificas del usuario (comando -> counter_logic_top)
	signal cmd_data_reg	: std_logic_vector(7 downto 0);
	signal cmd_data_valid	: std_logic;
	signal count_i		: std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal auto_mode_i	: std_logic; -- estado del modo automatico (feature extra)
	signal user_rst		: std_logic; -- reset activo en alto para counter_logic_top (VHDL-93 no permite expresiones en port map)

begin
	-- I/O Connections assignments
	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	<= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RDATA	<= axi_rdata;
	S_AXI_RRESP	<= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;

	-- axi_awready generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_awready <= '0';
	      aw_en <= '1';
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	        axi_awready <= '1';
	        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
	            aw_en <= '1';
	        	axi_awready <= '0';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- axi_awaddr latching
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_awaddr <= (others => '0');
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	        axi_awaddr <= S_AXI_AWADDR;
	      end if;
	    end if;
	  end if;
	end process;

	-- axi_wready generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_wready <= '0';
	    else
	      if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
	          axi_wready <= '1';
	      else
	        axi_wready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;

	-------------------------------------------------------------------------
	-- Seccion de usuario: captura del comando (registro de escritura)
	-------------------------------------------------------------------------
	process (S_AXI_ACLK)
	variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      cmd_data_reg   <= (others => '0');
	      cmd_data_valid <= '0';
	    else
	      loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
	      if (slv_reg_wren = '1' and loc_addr = REG_CMD_ADDR) then
	        cmd_data_reg   <= S_AXI_WDATA(7 downto 0);
	        cmd_data_valid <= '1';
	      else
	        cmd_data_valid <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- write response logic
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp   <= "00";
	    else
	      if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00";
	      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
	        axi_bvalid <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- axi_arready generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_arready <= '0';
	      axi_araddr  <= (others => '1');
	    else
	      if (axi_arready = '0' and S_AXI_ARVALID = '1') then
	        axi_arready <= '1';
	        axi_araddr  <= S_AXI_ARADDR;
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- axi_rvalid generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
	      if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
	        axi_rvalid <= '1';
	        axi_rresp  <= "00";
	      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
	        axi_rvalid <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

	-------------------------------------------------------------------------
	-- Seccion de usuario: mux de lectura (registro de comando y de contador)
	-------------------------------------------------------------------------
	process (axi_araddr, S_AXI_ARESETN, slv_reg_rden, count_i, auto_mode_i)
	variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
	begin
	    loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
	    case loc_addr is
	      when REG_CMD_ADDR =>
	        reg_data_out <= (others => '0'); -- registro de solo escritura
	      when REG_COUNT_ADDR =>
	        -- bits [COUNTER_WIDTH-1:0] = valor del contador
	        -- bit  [COUNTER_WIDTH]     = 1 si el modo automatico esta activo
	        reg_data_out <= (others => '0');
	        reg_data_out(COUNTER_WIDTH-1 downto 0) <= count_i;
	        reg_data_out(COUNTER_WIDTH) <= auto_mode_i;
	      when others =>
	        reg_data_out  <= (others => '0');
	    end case;
	end process;

	-- Output register (read data)
	process( S_AXI_ACLK ) is
	begin
	  if (rising_edge (S_AXI_ACLK)) then
	    if ( S_AXI_ARESETN = '0' ) then
	      axi_rdata  <= (others => '0');
	    else
	      if (slv_reg_rden = '1') then
	          axi_rdata <= reg_data_out;
	      end if;
	    end if;
	  end if;
	end process;

	-------------------------------------------------------------------------
	-- Instanciacion de la logica de usuario (cmd_decoder + counter)
	-------------------------------------------------------------------------
	user_rst <= not S_AXI_ARESETN; -- S_AXI_ARESETN es activo en bajo

	U1: entity work.counter_logic_top
        generic map (
            COUNTER_WIDTH     => COUNTER_WIDTH,
            AUTO_TICK_DIVISOR => AUTO_TICK_DIVISOR
        )
        port map (
            clk        => S_AXI_ACLK,
            rst        => user_rst,
            data_in    => cmd_data_reg,
            data_valid => cmd_data_valid,
            count      => count_i,
            auto_mode  => auto_mode_i
        );

end arch_imp;