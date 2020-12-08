-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2019 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): DOPLNIT
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

 -- zde dopiste potrebne deklarace signalu
  
 -- PC
	signal pc_reg : std_logic_vector(12 downto 0) := "0000000000000"; -- PC
	signal pc_inc : std_logic; 
	signal pc_dec : std_logic; 

	-- PTR
	signal ptr_reg : std_logic_vector(12 downto 0); 
	signal ptr_inc : std_logic; 
	signal ptr_dec : std_logic; 

	-- CNT
	signal cnt_reg : std_logic_vector(11 downto 0); 
	signal cnt_inc : std_logic; 
	signal cnt_dec : std_logic; 

	
	signal mx1 : std_logic_vector(7 downto 0);
	
	signal mx1_sel : std_logic;
	
	signal mx2 : std_logic_vector(7 downto 0);
	signal mx2_sel : std_logic;
	
	signal mx3 : std_logic_vector(7 downto 0);
	signal mx3_sel : std_logic_vector(1 downto 0);
	
	signal tmp_addr : std_logic_vector(12 downto 0);
	
	
	
	
	type fsm_state is (
		s_idle, 
		s_i_fetch, 
		s_i_decode, 
		s_inc_ptr, 
		s_dec_ptr, 
		s_inc_0, s_inc_1, s_inc_2, s_inc_3, 
		s_dec_0, s_dec_1, s_dec_2, s_dec_3, 
		s_while_0, s_while_1, s_while_2, s_while_code_en, 
		s_end_while_0, s_end_while_1, s_end_while_2, s_end_while_3, s_end_while_code_en, 
		s_putchar_0, s_putchar_1, s_putchar_2, 
		s_getchar_0, s_getchar_1, 
		s_break_0, s_break_1, s_break_code_en, 
		s_tmp_ptr0,
		s_tmp_ptr1,
		s_ptr_tmp0,
		s_ptr_tmp1,
		stav,
		s_return, 
		s_others 
	);
	signal fsm_pstate : fsm_state := s_idle; 
	signal fsm_nstate : fsm_state; 

begin

 -- zde dopiste vlastni VHDL kod


 -- pri tvorbe kodu reflektujte rady ze cviceni INP, zejmena mejte na pameti, ze 
 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --   - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --   - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly.
 
 -- PC SCITACKA
    process(CLK, RESET, pc_inc, pc_dec)
    begin
        if(RESET = '1') then
            pc_reg <= (others => '0');
        elsif(CLK'event and CLK = '1') then
            if(pc_inc = '1') then
		    if pc_reg ="0111111111111" then
			    pc_reg <=(others => '0');
		    else 
                	pc_reg <= pc_reg + 1;
		end if;	
            elsif(pc_dec = '1') then
		if pc_reg ="0000000000000" then		    
			pc_reg <="0111111111111";
		else
		       	pc_reg <= pc_reg - 1;
		end if;
            end if;
        end if;
    end process;
	 -- PTR SCITACKA
    process(CLK, RESET, ptr_inc, ptr_dec)
    begin
        if(RESET = '1') then
            ptr_reg <= "1000000000000";
        elsif(CLK'event and CLK = '1') then
            if(ptr_inc = '1') then
		if ptr_reg ="1111111111111" then
			ptr_reg <="1000000000000";
		else
                	ptr_reg <= ptr_reg + 1;
		end if;
            elsif(pc_dec = '1') then
		    if ptr_reg ="1000000000000" then
			ptr_reg <="1111111111111";
		    else
                	ptr_reg <= ptr_reg - 1;
		end if;
            end if;
        end if;
    end process;
	 --CNT SCITACKA
    process(CLK, RESET, cnt_inc, cnt_dec)
    begin
        if(RESET = '1') then
            cnt_reg <= (others => '0');
        elsif(CLK'event and CLK = '1') then
            if(cnt_inc = '1') then
                cnt_reg <= cnt_reg + 1;
            elsif(pc_dec = '1') then
                cnt_reg <= cnt_reg - 1;
            end if;
        end if;
    end process;
	 --END OF SCITACKY
	 
	 --MULTIPLEXORY
	 --vybera adresu
	process_mx1: process (CLK, RESET, mx1_sel)
	begin
		if RESET = '1' then
			DATA_ADDR <= (others => '0');
		elsif CLK'event and CLK = '1' then
			case mx1_sel is
				when '0'=>
					DATA_ADDR <= pc_reg;
				when '1' =>
					DATA_ADDR <= tmp_addr;
				when others =>
				null;
			end case;
		end if;
	end process;
	
	process_mx2: process (CLK, RESET, mx2_sel)
	begin
		if RESET = '1' then
			tmp_addr <= (others => '0');
		elsif CLK'event and CLK = '1' then
			case mx2_sel is
				when '0' =>
					tmp_addr <=ptr_reg;
				when '1' =>
					tmp_addr <=x"100" & '0';

				when others =>
				null;

			end case;
		end if;
	end process;
	
	 --multiplexor k volbe hodnoty z pamate 
		process_mx3: process (CLK, RESET, mx3_sel)
	begin
		if RESET = '1' then
			DATA_WDATA <= (others => '0');
		elsif CLK'event and CLK = '1' then
			case mx3_sel is
				when "00" =>
					DATA_WDATA <= IN_DATA;
				when "01" =>
					DATA_WDATA <= DATA_RDATA + 1;
				when "10" =>
					DATA_WDATA <= DATA_RDATA - 1;
				when "11" =>
					DATA_WDATA <= DATA_RDATA;
				when others =>
				null;
			end case;
		end if;
	end process;
	
	OUT_DATA <= DATA_RDATA;

	fsm_pstate_proc: process (CLK, RESET, EN)
	begin
		if RESET = '1' then
			fsm_pstate <= s_idle;
		elsif CLK'event and CLK = '1' then
			if EN = '1' then
				fsm_pstate <= fsm_nstate;
			end if;
		end if;
	end process;
	
	 
 
fsm_nstate_proc: process (fsm_pstate, OUT_BUSY, IN_VLD, cnt_reg, DATA_RDATA)
	begin
		-- inicializacia
		OUT_WE <= '0';
		IN_REQ <= '0';
		pc_inc <= '0';
		pc_dec <= '0';
		ptr_inc <= '0';
		ptr_dec <= '0';
		cnt_inc <= '0';
		cnt_dec <= '0';
		DATA_EN <= '0';
		mx1_sel<='0';
		mx2_sel<='0';
		mx3_sel<="00";
		DATA_RDWR <='0';
		--DATA_RDWR <= '0'asdasd;
		
		case fsm_pstate is
		--východzí stav
			when s_idle=>
				--ptr_reg <= x"100" & '0';
				--tmp_addr <= x"100" & '0';
				--nacitanie instrukcie
				fsm_nstate <= s_i_fetch;
			when s_i_fetch=>
				--DATA_EN <= '1';
				
				fsm_nstate <= stav;
			when stav=>
				DATA_EN <= '1';
				fsm_nstate <= s_i_decode;
				--dekodovanie instrukcii
			when s_i_decode =>
                case(DATA_RDATA) is
                    					when X"3E" =>
						  --ptr = ptr+1
								fsm_nstate <= s_inc_ptr;
							when X"3C" =>
							--ptr = ptr- 1
								fsm_nstate <= s_dec_ptr;
							when X"2B" =>
							--*ptr += 1
								fsm_nstate <= s_inc_0;
							when X"2D"=>
								fsm_nstate <= s_dec_0;
							when X"5B" =>
								fsm_nstate <= s_while_0;
							when X"5D" =>
								fsm_nstate <= s_end_while_0;
							when X"2E"=>
								fsm_nstate <= s_putchar_0;
							when X"2C"=>
								fsm_nstate <= s_getchar_0;
								--tmp = *ptr
							when X"24"=>
								fsm_nstate <= s_tmp_ptr0;
								--*ptr = tmp
							when X"21"=>
								fsm_nstate <= s_ptr_tmp0;
							when X"00"=>
								fsm_nstate <= s_return;
							when others =>
								fsm_nstate <= s_others;
                end case;
					 
			---------- > - inkrementace hodnoty ukazatele
			when s_inc_ptr =>
				ptr_inc <= '1'; -- PTR += 1
				pc_inc <= '1'; -- PC += 1

				fsm_nstate <= s_i_fetch;


			---------- < - dekrementace hodnoty ukazatele
			when s_dec_ptr =>
				ptr_dec <= '1'; -- PTR -= 1
				pc_inc <= '1'; -- PC += 1

				fsm_nstate <= s_i_fetch;


			---------- + - inkrementace hodnoty aktuální buòky
			when s_inc_0 =>
				
				--nastavenie multiplexorov
				mx2_sel<= '0';
				mx1_sel <= '1';
				
				fsm_nstate <= s_inc_1;
			when s_inc_1 =>
				--precitanie z addr a ulozit do rdata
				DATA_EN <= '1';
				DATA_RDWR <='0';
				fsm_nstate<= s_inc_2;
			when s_inc_2 =>
			--dalsie nastavenie multiplexorov
					mx1_sel <= '1';
					mx3_sel <= "01";
					fsm_nstate<=s_inc_3;
					
			when s_inc_3 =>
				--zapis data+1
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				pc_inc	<= '1';
				fsm_nstate <=s_i_fetch;				
			----------- - dekrementace hodnoty aktuální buòky
			when s_dec_0 =>
				mx2_sel <= '0'; -- ptr register
				mx1_sel <= '1';--vystup z mx2
				
				fsm_nstate <= s_dec_1; --dalsi state pre update

			when s_dec_1 =>
				DATA_EN<='1';
				DATA_RDWR<='0'; --en 1 rdwr 0 pre nacitanie

				fsm_nstate <= s_dec_2;
			when s_dec_2=>
				mx1_sel <='1'; --znova ptr reg
				mx3_sel <= "10"; -- DATA_WDATA -= 1
			when s_dec_3 =>
				DATA_EN <= '1';
				DATA_RDWR <= '1'; --en 1 rdwr 1 pre zapis

				pc_inc <= '1'; -- PC += 1

				fsm_nstate <= s_i_fetch;

	--		when s_putchar_0 =>
	--			-- data v DATA_RDATA
	--			DATA_EN <= '1';
	--			DATA_RDWR <= '0';
				--mx2_sel <= '0';
				--mx1_sel<='1';
	--			fsm_nstate <= s_putchar_1;

		--	when s_putchar_1 =>
		--		if OUT_BUSY = '1' then
					-- DATA_RDATA = RAM[PTR]
		--			DATA_EN <= '1';
		--			DATA_RDWR <= '0';

--					fsm_nstate <= s_putchar_1;
	--			else
		--			OUT_WE <= '1'; -- OUT_DATA = DATA_RDATA

			--		pc_inc <= '1'; -- PC += 1
			--		OUT_DATA <= DATA_RDATA;
			--		fsm_nstate <= s_i_fetch;
			--	end if;
				
		when s_putchar_0 =>
			mx1_sel <= '1';
			mx2_sel<='0';
			fsm_nstate <= s_putchar_1;
		when s_putchar_1=>
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			fsm_nstate <= s_putchar_2;
		when s_putchar_2 =>
			fsm_nstate <= s_putchar_2;
			if (OUT_BUSY = '0') then
				OUT_WE <= '1';
				pc_inc <= '1';
				fsm_nstate <= s_i_fetch;
			end if;


			---------- , - naètení hodnoty do aktuální buòky
			when s_getchar_0 =>
				IN_REQ <= '1';
				mx3_sel <= "00"; -- DATA_WDATA = IN_DATA

				fsm_nstate <= s_getchar_1;

			when s_getchar_1 =>
				if IN_VLD /= '1' then
					IN_REQ <= '1';
					mx3_sel <= "00"; -- DATA_WDATA = IN_DATA

					fsm_nstate <= s_getchar_1;
				else
					-- RAM[PTR] = DATA_WDATA
					DATA_EN <= '1';
					DATA_RDWR <= '1';

					pc_inc <= '1'; -- PC += 1

					fsm_nstate <= s_i_fetch;
				end if;

			when s_tmp_ptr0=>
								mx2_sel <= '0'; --multiplexor 2 na 0
								DATA_EN <='1';
								DATA_RDWR <= '0';
								mx1_sel <=  '1'; --mux 1 na 1
								
								fsm_nstate <= s_tmp_ptr1;
			when s_tmp_ptr1=>
								mx2_sel <= '1'; --0x100
								DATA_EN <='1';
								DATA_RDWR <= '0';
								mx1_sel <=  '1'; --mux 1 na 1
								
								mx3_sel <= "11";
								fsm_nstate <= s_i_fetch;
			when s_ptr_tmp0=>
								mx2_sel <= '0';--ptr
								DATA_EN <= '1';
								DATA_RDWR <= '0';--citanie
								mx1_sel <= '1';--ptr
								
			when s_ptr_tmp1=>
								mx2_sel <= '1';
								mx1_sel <= '1';--nacitam adresu tmp
								--zapisujem
								DATA_EN <= '1';
								DATA_RDWR <= '1';
								
								mx3_sel <= "11";
								
								fsm_nstate <= s_i_fetch;
			when s_return =>
				fsm_nstate <= s_return;


			---------- ostatní
			when s_others =>
				pc_inc <= '1'; -- PC += 1

				fsm_nstate <= s_i_fetch;
				
			when others=>
				null;
		end case;
	end process;
end behavioral;

--						DATA_RDATA <= ptr_reg;
	--							DATA_ADDR <= x"100" & '0';
	--							DATA_EN <= '1';
	--							DATA_RDWR <= '1';


--							--prvz takt

								--druhz takt
