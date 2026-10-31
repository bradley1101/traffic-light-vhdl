--------------------------------------------------------------------------------
-- Self-checking testbench for traffic_light
--
-- CLK_HZ = 10 -> one "second" of the controller = 10 clock cycles = 100 ns,
-- so a full cycle simulates in a few microseconds.
--
-- Checks:
--   1. Safety (every clock): never green/yellow on both roads, exactly one
--      lamp per road, pedestrians walk only when the main road is red.
--   2. Main road stays green while nobody waits on the side road.
--   3. A vehicle on the side road gets green after the full sequence.
--   4. Phase durations (green / yellow / all-red) match the generics.
--   5. Pedestrian request is served.
--   6. Night mode blinks yellow on both roads, then returns to normal.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity tb_traffic_light is
end entity;

architecture sim of tb_traffic_light is

  constant CLK_HZ   : positive := 10;
  constant CLK_T    : time     := 10 ns;
  constant SEC      : time     := CLK_HZ * CLK_T;   -- 100 ns
  constant T_MAIN_G : positive := 5;
  constant T_SIDE_G : positive := 4;
  constant T_YELLOW : positive := 2;
  constant T_ALL_RED: positive := 1;

  signal clk, rst                         : std_logic := '0';
  signal side_sensor, ped_request, night  : std_logic := '0';
  signal m_r, m_y, m_g, s_r, s_y, s_g, walk : std_logic;
  signal state_dbg                        : std_logic_vector(2 downto 0);
  signal done                             : boolean := false;

  -- helpers ------------------------------------------------------------------
  function lamps (r, y, g : std_logic) return natural is
    variable n : natural := 0;
  begin
    if r = '1' then n := n + 1; end if;
    if y = '1' then n := n + 1; end if;
    if g = '1' then n := n + 1; end if;
    return n;
  end function;

begin

  clk <= not clk after CLK_T / 2 when not done;

  dut : entity work.traffic_light
    generic map (CLK_HZ => CLK_HZ, T_MAIN_G => T_MAIN_G, T_SIDE_G => T_SIDE_G,
                 T_YELLOW => T_YELLOW, T_ALL_RED => T_ALL_RED)
    port map (clk => clk, rst => rst, side_sensor => side_sensor,
              ped_request => ped_request, night_mode => night,
              main_red => m_r, main_yellow => m_y, main_green => m_g,
              side_red => s_r, side_yellow => s_y, side_green => s_g,
              ped_walk => walk, state_dbg => state_dbg);

  ------------------------------------------------------------------------------
  -- 1. Safety monitor
  ------------------------------------------------------------------------------
  p_safety : process (clk)
  begin
    if falling_edge(clk) and rst = '0' then
      assert not (m_g = '1' and s_g = '1')
        report "SAFETY: both roads green" severity failure;
      if night = '0' and state_dbg /= "110" then
        assert lamps(m_r, m_y, m_g) = 1 report "SAFETY: main road must show exactly one lamp" severity failure;
        assert lamps(s_r, s_y, s_g) = 1 report "SAFETY: side road must show exactly one lamp" severity failure;
        assert not ((m_g = '1' or m_y = '1') and (s_g = '1' or s_y = '1'))
          report "SAFETY: conflicting green/yellow" severity failure;
      end if;
      assert not (walk = '1' and m_r = '0')
        report "SAFETY: pedestrians walking while main road is not red" severity failure;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Scenario
  ------------------------------------------------------------------------------
  p_stim : process
    variable t0 : time;

    -- wait until a signal becomes '1', with a timeout
    procedure wait_high (signal s : std_logic; timeout : time; msg : string) is
    begin
      if s /= '1' then
        wait until s = '1' for timeout;
      end if;
      assert s = '1' report "TIMEOUT waiting for " & msg severity failure;
    end procedure;

    -- measure how long a signal stays high, compare to the expected seconds
    procedure check_duration (signal s : std_logic; expected : positive; msg : string) is
      variable t_start : time;
    begin
      wait_high(s, 50 * SEC, msg);
      t_start := now;
      wait until s = '0';
      assert (now - t_start) = expected * SEC
        report msg & " lasted " & time'image(now - t_start) & ", expected "
               & time'image(expected * SEC) severity failure;
      report msg & " duration OK (" & integer'image(expected) & " s)";
    end procedure;

  begin
    rst <= '1';
    wait for 3 * CLK_T;
    wait until falling_edge(clk);
    rst <= '0';

    -- 2. no vehicle: the main road keeps the green
    wait_high(m_g, 5 * SEC, "main green after reset");
    wait for 3 * T_MAIN_G * SEC;
    assert m_g = '1' and s_r = '1'
      report "Main road should stay green when nobody waits" severity failure;
    report "Test 2 OK: main road stays green without demand";

    -- 3 + 4. vehicle on the side road
    side_sensor <= '1';
    check_duration(m_y, T_YELLOW, "Main yellow");
    t0 := now;
    wait_high(s_g, 5 * SEC, "side green");
    assert now - t0 = T_ALL_RED * SEC
      report "All-red clearance has wrong duration: " & time'image(now - t0) severity failure;
    report "All-red clearance OK";
    side_sensor <= '0';
    wait until s_g = '0';
    wait_high(s_y, SEC, "side yellow");
    check_duration(s_y, T_YELLOW, "Side yellow");
    -- a pedestrian presses the button during this green (process p_ped):
    -- the main road must leave green exactly after its minimum time
    check_duration(m_g, T_MAIN_G, "Main green (pedestrian waiting)");
    report "Test 3/4 OK: side road served, phase durations correct";

    -- 5. pedestrian: walk signal during the next side phase
    wait_high(walk, 20 * SEC, "pedestrian walk");
    report "Test 5 OK: pedestrian served";

    -- 6. night mode
    wait until m_g = '1';
    night <= '1';
    wait for 2 * CLK_T;
    assert m_g = '0' and s_g = '0' report "Night mode: greens must be off" severity failure;
    wait_high(m_y, 2 * SEC, "night blink on");
    wait until m_y = '0' for 2 * SEC;
    assert m_y = '0' report "Night mode: yellow does not blink" severity failure;
    wait_high(m_y, 2 * SEC, "night blink on again");
    assert s_y = '1' report "Night mode: side yellow must blink with main" severity failure;
    report "Test 6 OK: night mode blinks";
    night <= '0';
    wait_high(m_g, 5 * SEC, "back to day mode");
    report "Back to normal cycle";

    report "ALL TESTS PASSED" severity note;
    done <= true;
    wait;
  end process;

  -- pedestrian presses the button while the main road is green (after test 3)
  p_ped : process
  begin
    wait until s_y = '1';          -- end of first side phase
    wait until m_g = '1';
    wait for 2 * SEC;
    ped_request <= '1';
    wait for CLK_T;
    ped_request <= '0';
    wait;
  end process;

end architecture;
