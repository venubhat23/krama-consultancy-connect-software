class DropStaleMembershipAndReferralTables < ActiveRecord::Migration[8.0]
  # Some environments have an obsolete, pre-redesign version of these tables
  # (missing columns the current app relies on, e.g. `token`/`referrer_id`).
  # They predate the current create_table migrations and hold no rows worth
  # keeping, so drop them here and let those migrations recreate the
  # current shape cleanly.
  def up
    if table_exists?(:membership_applications) && !column_exists?(:membership_applications, :token)
      drop_table :membership_applications
    end

    if table_exists?(:referrals) && !column_exists?(:referrals, :referrer_id)
      drop_table :referrals, force: :cascade
    end
  end

  def down
    # No-op: the original create_table migrations (20260708170000, 20260709000001) recreate these.
  end
end
