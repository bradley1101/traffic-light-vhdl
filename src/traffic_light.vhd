--------------------------------------------------------------------------------
-- Traffic light controller for a two-road intersection (main road / side road)
--
-- * Moore finite state machine, 6 states, with an all-red safety phase
--   between every change of direction.
-- * The side road only gets green when a vehicle is detected (side_sensor),
--   after the main road has had at least its minimum green time.
-- * Pedestrian request on the main road crossing (ped_request) is served
--   during the side-road green phase (main road stopped).
-- * Night mode: both directions blink yellow (1 s on / 1 s off).
--
-- Timings are given in seconds and converted with the CLK_HZ generic,
-- so the same code runs on a board (50 MHz) and in simulation (tiny CLK_HZ).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity traffic_light is
  generic (
    CLK_HZ     : positive := 50_000_000;  -- system clock frequency
    T_MAIN_G   : positive := 20;          -- main road minimum green (s)
    T_SIDE_G   : positive := 10;          -- side road green (s)
    T_YELLOW   : positive := 3;           -- yellow (s)
    T_ALL_RED  : positive := 1            -- all-red safety clearance (s)
  );
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;          -- synchronous, active high
    side_sensor : in  std_logic;          -- vehicle waiting on the side road
    ped_request : in  std_logic;          -- pedestrian button (latched)
    night_mode  : in  std_logic;          -- blinking yellow when '1'
    -- main road lights
    main_red    : out std_logic;
    main_yellow : out std_logic;
    main_green  : out std_logic;
    -- side road lights
    side_red    : out std_logic;
    side_yellow : out std_logic;
    side_green  : out std_logic;
    -- pedestrian signal crossing the main road
    ped_walk    : out std_logic;
    -- debug: current state number (0..6)
    state_dbg   : out std_logic_vector(2 downto 0)
  );
end entity;

architecture rtl of traffic_light is

  type state_t is (S_MAIN_GREEN, S_MAIN_YELLOW, S_ALL_RED_1, S_SIDE_GREEN, S_SIDE_YELLOW, S_ALL_RED_2, S_NIGHT);
  signal state : state_t := S_ALL_RED_2;

  -- 1-second tick generator
  signal tick_cnt : natural range 0 to CLK_HZ - 1 := 0;
  signal tick     : std_logic := '0';

  -- seconds spent in the current state
  signal sec_cnt  : natural range 0 to 255 := 0;

  signal ped_latched : std_logic := '0';
  signal blink       : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  -- 1 Hz tick
  ------------------------------------------------------------------------------
  p_tick : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        tick_cnt <= 0;
        tick     <= '0';
      elsif tick_cnt = CLK_HZ - 1 then
        tick_cnt <= 0;
        tick     <= '1';
      else
        tick_cnt <= tick_cnt + 1;
        tick     <= '0';
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- State register + next-state logic
  ------------------------------------------------------------------------------
  p_fsm : process (clk)
    procedure go (s : state_t) is
    begin
      state   <= s;
      sec_cnt <= 0;
    end procedure;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state       <= S_ALL_RED_2;
        sec_cnt     <= 0;
        ped_latched <= '0';
        blink       <= '0';
      else
        -- pedestrian button is latched until served
        if ped_request = '1' then
          ped_latched <= '1';
        end if;

        if night_mode = '1' and state /= S_NIGHT then
          go(S_NIGHT);
        elsif tick = '1' then
          sec_cnt <= sec_cnt + 1;
          case state is
            when S_MAIN_GREEN =>
              -- leave only after the minimum green AND if someone is waiting
              if sec_cnt + 1 >= T_MAIN_G and (side_sensor = '1' or ped_latched = '1') then
                go(S_MAIN_YELLOW);
              end if;

            when S_MAIN_YELLOW =>
              if sec_cnt + 1 >= T_YELLOW then go(S_ALL_RED_1); end if;

            when S_ALL_RED_1 =>
              if sec_cnt + 1 >= T_ALL_RED then go(S_SIDE_GREEN); end if;

            when S_SIDE_GREEN =>
              if sec_cnt + 1 >= T_SIDE_G then
                go(S_SIDE_YELLOW);
                ped_latched <= '0';      -- pedestrians have been served
              end if;

            when S_SIDE_YELLOW =>
              if sec_cnt + 1 >= T_YELLOW then go(S_ALL_RED_2); end if;

            when S_ALL_RED_2 =>
              if sec_cnt + 1 >= T_ALL_RED then go(S_MAIN_GREEN); end if;

            when S_NIGHT =>
              blink <= not blink;
              if night_mode = '0' then go(S_ALL_RED_2); end if;
          end case;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Moore outputs
  ------------------------------------------------------------------------------
  main_green  <= '1' when state = S_MAIN_GREEN else '0';
  main_yellow <= '1' when state = S_MAIN_YELLOW or (state = S_NIGHT and blink = '1') else '0';
  main_red    <= '1' when state = S_ALL_RED_1 or state = S_SIDE_GREEN or state = S_SIDE_YELLOW or state = S_ALL_RED_2 else '0';

  side_green  <= '1' when state = S_SIDE_GREEN else '0';
  side_yellow <= '1' when state = S_SIDE_YELLOW or (state = S_NIGHT and blink = '1') else '0';
  side_red    <= '1' when state = S_MAIN_GREEN or state = S_MAIN_YELLOW or state = S_ALL_RED_1 or state = S_ALL_RED_2 else '0';

  ped_walk    <= '1' when state = S_SIDE_GREEN else '0';

  state_dbg   <= std_logic_vector(to_unsigned(state_t'pos(state), 3));

end architecture;
