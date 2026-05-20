-- Replace the older result shape constraint that predates false win penalties.

alter table public.hand_results
  drop constraint if exists hand_results_result_shape_check;

alter table public.hand_results
  drop constraint if exists hand_results_shape_check;

alter table public.hand_results
  add constraint hand_results_result_shape_check
  check (
    (
      result_type = 'washout'
      and winner_seat_index is null
      and win_type is null
      and discarder_seat_index is null
      and penalty_seat_index is null
      and fan_count is null
      and base_points is null
    )
    or
    (
      result_type = 'win'
      and winner_seat_index is not null
      and penalty_seat_index is null
      and fan_count is not null
      and fan_count >= 3
      and win_type is not null
      and (
        (
          win_type = 'discard'
          and discarder_seat_index is not null
          and discarder_seat_index <> winner_seat_index
        )
        or
        (
          win_type = 'self_draw'
          and discarder_seat_index is null
        )
      )
    )
    or
    (
      result_type = 'false_win_penalty'
      and winner_seat_index is null
      and win_type is null
      and discarder_seat_index is null
      and penalty_seat_index is not null
      and fan_count = 6
    )
  );

select pg_notify('pgrst', 'reload schema');
