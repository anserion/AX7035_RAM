--Copyright 2025 Andrey S. Ionisyan (anserion@gmail.com)
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--    http://www.apache.org/licenses/LICENSE-2.0
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
------------------------------------------------------------------

library IEEE; use IEEE.STD_LOGIC_1164.ALL;

entity RAM_top is
    Port (SYS_CLK,KEY1,KEY2,KEY3,KEY4,RESET: in STD_LOGIC;
          SMG_DATA : out  STD_LOGIC_VECTOR (7 downto 0);
          SCAN_SIG : out  STD_LOGIC_VECTOR (5 downto 0));
end RAM_top;

architecture Behavioral of RAM_top is
component CLK_GEN
  Generic (TICKS_PER_SIGNAL: natural);
  Port (CLK_IN,EN,RESET: in STD_LOGIC; CLK_OUT : out  STD_LOGIC);
end component;
component SMG_x16_driver is
    Port (clk,en: in std_logic; NUM_16x: in STD_LOGIC_VECTOR(23 downto 0); 
          mask_dp, mask_dig: in STD_LOGIC_VECTOR(5 downto 0);
          SEG: out STD_LOGIC_VECTOR(7 downto 0);
          DIG: out STD_LOGIC_VECTOR(5 downto 0));
end component;
component keys_supervisor
   Generic (debounce: in natural range 0 to 1023);
   Port (clk,en: in std_logic; key1,key2,key3,key4,reset: in std_logic; 
         key_code: out std_logic_vector(3 downto 0); RDY: out std_logic);
end component;
component RAM_2NxM is
    generic (N:natural range 1 to 32:=0; M:natural range 1 to 32:=8);
    port (CLKA : in std_logic;
          WEA  : in std_logic_vector(0 downto 0);
          ADDRA: in std_logic_vector(N-1 downto 0);
          DINA : in std_logic_vector(M-1 downto 0);
          ADDRB: in std_logic_vector(N-1 downto 0);
          DOUTB: out std_logic_vector(M-1 downto 0)
    );
end component;
signal CLK, CLK_SMG: std_logic;
signal wea: std_logic_vector(0 downto 0):="0";
signal addra,addrb:std_logic_vector(2 downto 0):="000";
signal dina,doutb: std_logic_vector(3 downto 0):="0000";
signal put1, put2, put3, get1, get2, get3: std_logic_vector(3 downto 0):="0000";
signal key_code: std_logic_vector(3 downto 0):="0000";
signal key_ready: std_logic;

begin
  CLK_GEN_1MHz_chip: CLK_GEN generic map(50) port map(SYS_CLK,'1','0',CLK);
  CLK_GEN_10kHz_SMG: CLK_GEN generic map(5000) port map(SYS_CLK,'1','0',CLK_SMG);
  SMG_x16_driver_chip: SMG_x16_driver port map(CLK_SMG, '1',
                                               put1 & put2 & put3 & get1 & get2 & get3,
                                               "110111", "000000",SMG_DATA, SCAN_SIG);
  KEYS_driver: keys_supervisor generic map(500)
                               port map(CLK,'1',KEY1,KEY2,KEY3,KEY4,RESET,key_code,key_ready);
  RAM_chip: RAM_2NxM generic map(3,4) port map(SYS_CLK,wea,addra,dina,addrb,doutb);
  
  process(CLK)
  variable fsm: natural range 0 to 31:=0;
  begin
    if rising_edge(CLK) then
      case fsm is
      when 0=>fsm:=1; addrb<="000"; addra<="000"; dina<="0000"; wea<="1";
      -----------------------------------------------------------------
      when 1=>if key_ready='0' then fsm:=2; end if;
      when 2=>if key_ready='1' then fsm:=3; put1<=key_code; end if;
      when 3=>if key_ready='0' then fsm:=4; end if;
      when 4=>if key_ready='1' then fsm:=5; put2<=key_code; end if;
      when 5=>if key_ready='0' then fsm:=6; end if;
      when 6=>if key_ready='1' then fsm:=7; put3<=key_code; end if;
      when 7=>if key_ready='0' then fsm:=8; end if;
      when 8=>if key_ready='1' and key_code="0111" then fsm:=9; end if;
      -----------------------------------------------------------------
      when 9=>fsm:=10;  addra<="001"; 
      when 10=>fsm:=11; dina<=put1;
      when 11=>fsm:=12; addra<="010"; 
      when 12=>fsm:=13; dina<=put2;
      when 13=>fsm:=14; addra<="011"; 
      when 14=>fsm:=15; dina<=put3;
      when 15=>fsm:=16;
      -----------------------------------------------------------------
      when 16=>fsm:=17; addrb<="001"; 
      when 17=>fsm:=18; get1<=doutb;
      when 18=>fsm:=19; addrb<="010";
      when 19=>fsm:=20; get2<=doutb;
      when 20=>fsm:=21; addrb<="011"; 
      when 21=>fsm:=22; get3<=doutb;
      when 22=>fsm:=1;
      -----------------------------------------------------------------
      when others=>null;
      end case;
    end if;
  end process;
end Behavioral;
