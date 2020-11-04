----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:38:37 09/18/2020 
-- Design Name: 
-- Module Name:    DFT - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity DFT is
	Generic (BINS : integer);
    Port ( CLK : in  STD_LOGIC;
           RESET : in  STD_LOGIC;
           PORT1 : in  STD_LOGIC_VECTOR (15 downto 0);
           PORT2 : in  STD_LOGIC_VECTOR (15 downto 0);
           NEW_SAMPLE : in  STD_LOGIC;
			  NSAMPLES : in STD_LOGIC_VECTOR (15 downto 0);
           BIN1_PHASEINC : in  STD_LOGIC_VECTOR (15 downto 0);
           DIFFBIN_PHASEINC : in  STD_LOGIC_VECTOR (15 downto 0);
			  WINDOW_INC : in STD_LOGIC_VECTOR (15 downto 0);
			  WINDOW_TYPE : in STD_LOGIC_VECTOR (1 downto 0);
           RESULT_READY : out  STD_LOGIC;
           OUTPUT : out  STD_LOGIC_VECTOR (191 downto 0);
           NEXT_OUTPUT : in  STD_LOGIC);
end DFT;

architecture Behavioral of DFT is
COMPONENT dft_result
GENERIC(depth : integer);
PORT(
	CLK : IN std_logic;
	READ_ADDRESS : in integer range 0 to depth-1;
	WRITE_ADDRESS : in integer range 0 to depth-1;
	DATA_IN : IN std_logic_vector(191 downto 0);
	WE : IN std_logic;          
	DATA_OUT : OUT std_logic_vector(191 downto 0)
	);
END COMPONENT;
COMPONENT result_bram
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(191 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(191 DOWNTO 0)
  );
END COMPONENT;
COMPONENT SinCos
  PORT (
    clk : IN STD_LOGIC;
    phase_in : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    cosine : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    sine : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;
COMPONENT SinCosMult
  PORT (
    clk : IN STD_LOGIC;
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    b : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    p : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;
COMPONENT window
PORT(
	CLK : IN std_logic;
	INDEX : IN std_logic_vector(6 downto 0);
	WINDOW_TYPE : IN std_logic_vector(1 downto 0);          
	VALUE : OUT std_logic_vector(15 downto 0)
	);
END COMPONENT;

	--type result is array(BINS-1 downto 0) of std_logic_vector(47 downto 0);
	--signal port1_real : result;
	--signal port1_imag : result;
	--signal port2_real : result;
	--signal port2_imag : result;
	
	--signal port1_real_read : std_logic_vector(47 downto 0);
	--signal port1_imag_read : std_logic_vector(47 downto 0);
	--signal port2_real_read : std_logic_vector(47 downto 0);
	--signal port2_imag_read : std_logic_vector(47 downto 0);
	
	signal sample_cnt : integer range 0 to 65535;
	signal bin_cnt : integer range 0 to BINS+2;
	
	signal read_address : integer range 0 to BINS-1;
	signal write_address : integer range 0 to BINS-1;
	signal read_address_vector : std_logic_vector(5 downto 0);
	signal write_address_vector : std_logic_vector(5 downto 0);
	signal we : std_logic_vector(0 downto 0);
	signal ram_in : std_logic_vector(191 downto 0);
	signal ram_out : std_logic_vector(191 downto 0);
	
	type States is (WaitingForSample, WaitMult, WaitMult2, PhaseReady, WindowingReady, WaitSinCos, Busy, Ready);
	signal state : States;
	signal port1_latch : std_logic_vector(15 downto 0);
	signal port2_latch : std_logic_vector(15 downto 0);
	
	signal window_index : std_logic_vector(15 downto 0);

	signal window_value : std_logic_vector(15 downto 0);
	
	signal phase : std_logic_vector(31 downto 0);
	signal phase_inc : std_logic_vector(31 downto 0);
	signal sine : std_logic_vector(15 downto 0);
	signal cosine : std_logic_vector(15 downto 0);
	
	signal mult1_a : std_logic_vector(15 downto 0);
	signal mult1_b : std_logic_vector(15 downto 0);
	signal mult1_p : std_logic_vector(31 downto 0);
	
	signal mult2_a : std_logic_vector(15 downto 0);
	signal mult2_b : std_logic_vector(15 downto 0);
	signal mult2_p : std_logic_vector(31 downto 0);
	
	signal mult3_a : std_logic_vector(15 downto 0);
	signal mult3_b : std_logic_vector(15 downto 0);
	signal mult3_p : std_logic_vector(31 downto 0);
	
	signal mult4_a : std_logic_vector(15 downto 0);
	signal mult4_b : std_logic_vector(15 downto 0);
	signal mult4_p : std_logic_vector(31 downto 0);
begin

	LookupTable : SinCos
	PORT MAP (
		clk => CLK,
		phase_in => phase(31 downto 20),
		cosine => cosine,
		sine => sine
	);
	Mult1 : SinCosMult
	PORT MAP (
		clk => CLK,
		a => mult1_a,
		b => mult1_b,
		p => mult1_p
	);
	Mult2 : SinCosMult
	PORT MAP (
		clk => CLK,
		a => mult2_a,
		b => mult2_b,
		p => mult2_p
	);
	Mult3 : SinCosMult
	PORT MAP (
		clk => CLK,
		a => mult3_a,
		b => mult3_b,
		p => mult3_p
	);
	Mult4 : SinCosMult
	PORT MAP (
		clk => CLK,
		a => mult4_a,
		b => mult4_b,
		p => mult4_p
	);
	WindowROM: window PORT MAP(
		CLK => CLK,
		INDEX => window_index(15 downto 9),
		WINDOW_TYPE => WINDOW_TYPE,
		VALUE => window_value
	);
	
--	result_ram: dft_result
--	GENERIC MAP(depth => BINS)
--	PORT MAP(
--		CLK => CLK,
--		READ_ADDRESS => read_address,
--		WRITE_ADDRESS => write_address,
--		DATA_IN => ram_in,
--		DATA_OUT => ram_out,
--		WE => we
--	);

your_instance_name : result_bram
  PORT MAP (
    clka => CLK,
    wea => we,
    addra => write_address_vector,
    dina => ram_in,
    clkb => CLK,
    addrb => read_address_vector,
    doutb => ram_out
  );
	
	read_address_vector <= std_logic_vector(to_unsigned(read_address, 6));
	write_address_vector <= std_logic_vector(to_unsigned(write_address, 6));
	OUTPUT <= ram_out;
	
	process(CLK, RESET)
	begin
		if rising_edge(CLK) then
			if RESET = '1' then
				window_index <= (others => '0');
				sample_cnt <= 0;
				RESULT_READY <= '0';
				read_address <= 0;
				write_address <= 0;
				we <= "0";
				state <= WaitingForSample;
			else
				case state is
					when WaitingForSample =>
						we <= "0";
						if NEW_SAMPLE = '1' then
							-- calculate phase for initial bin
							-- TODO this should use unsigned multiplication
							mult1_a <= std_logic_vector(to_unsigned(sample_cnt, 16));
							mult1_b <= BIN1_PHASEINC;
							mult2_a <= std_logic_vector(to_unsigned(sample_cnt, 16));
							mult2_b <= DIFFBIN_PHASEINC;
							-- window ADC data
							mult3_a <= PORT1;
							mult3_b <= window_value;
							mult4_a <= PORT2;
							mult4_b <= window_value;
							state <= WaitMult;
							read_address <= 0;
						end if;
					when WaitMult =>
						RESULT_READY <= '0';
						we <= "0";
						state <= WaitMult2;
					when WaitMult2 =>
						RESULT_READY <= '0';
						we <= "0";
						state <= PhaseReady;							
					when PhaseReady =>
						RESULT_READY <= '0';
						we <= "0";
						-- initial phase is ready
						phase <= mult1_p(15 downto 0) & "0000000000000000";
						phase_inc <= mult2_p(23 downto 0) & "00000000";
						state <= WindowingReady;
					when WindowingReady =>
						RESULT_READY <= '0';
						we <= "0";
						phase <= std_logic_vector(unsigned(phase)+unsigned(phase_inc));
						port1_latch <= mult3_p(31 downto 16);
						port2_latch <= mult4_p(31 downto 16);
						bin_cnt <= 0;
						state <= WaitSinCos;
					when WaitSinCos =>
						phase <= std_logic_vector(unsigned(phase)+unsigned(phase_inc));
						RESULT_READY <= '0';
						we <= "0";
						if bin_cnt < 4 then
							bin_cnt <= bin_cnt + 1;
						else
							bin_cnt <= 0;
							state <= BUSY;
						end if;
					when BUSY =>
						RESULT_READY <= '0';
						phase <= std_logic_vector(unsigned(phase)+unsigned(phase_inc));
						mult1_a <= port1_latch;
						mult1_b <= sine;
						mult2_a <= port1_latch;
						mult2_b <= cosine;
						mult3_a <= port2_latch;
						mult3_b <= sine;
						mult4_a <= port2_latch;
						mult4_b <= cosine;
						if bin_cnt >= 3 then
							-- multiplier result is available, accumulate
							we <= "1";
							write_address <= bin_cnt - 3;
							ram_in <= std_logic_vector(signed(ram_out(191 downto 144))+signed(mult1_p))
										& std_logic_vector(signed(ram_out(143 downto 96))+signed(mult2_p))
										& std_logic_vector(signed(ram_out(95 downto 48))+signed(mult3_p))
										& std_logic_vector(signed(ram_out(47 downto 0))+signed(mult4_p));
						else
							we <= "0";
						end if;
						if bin_cnt >= BINS+2 then
							read_address <= 0;
							if sample_cnt < unsigned(NSAMPLES) then
								sample_cnt <= sample_cnt + 1;
								state <= WaitingForSample;
								window_index <= std_logic_vector(unsigned(window_index)+unsigned(WINDOW_INC));
							else
								state <= Ready;
							end if;
						else
							bin_cnt <= bin_cnt + 1;
							if bin_cnt >= 1 then
								read_address <= bin_cnt - 1;
							end if;
						end if;
					when Ready =>
						we <= "0";
						RESULT_READY <= '1';
						if NEXT_OUTPUT = '1' then
							-- reset last entry to prepare for next DFT
							write_address <= read_address;
							ram_in <= (others => '0');
							we <= "1";
							-- fetch next entry from RAM
							if read_address < BINS - 1 then
								read_address <= read_address + 1;
							else
								RESULT_READY <= '0';
								sample_cnt <= 0;
								state <= WaitingForSample;
								read_address <= 0;
							end if;
						end if;
					when others =>
						state <= WaitingForSample;
				end case;
			end if;
		end if;
	end process;


end Behavioral;

