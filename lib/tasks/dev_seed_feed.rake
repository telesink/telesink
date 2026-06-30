require "set"

namespace :dev do
  desc "Seed development sinks with IRC-style feed playground data"
  task seed_feed: :environment do
    abort "dev:seed_feed only runs in development." unless Rails.env.development?

    result = DevelopmentFeedSeeder.new.call

    puts "Seeded feed playground for #{result.fetch(:user).email_address}:"
    if result.fetch(:deleted_sinks).any?
      puts "Removed sinks: #{result.fetch(:deleted_sinks).join(", ")}"
    end

    if result.fetch(:deleted_folders).any?
      puts "Removed folders: #{result.fetch(:deleted_folders).join(", ")}"
    end

    result.fetch(:sinks).each do |entry|
      puts "  #{entry.fetch(:folder).name}/#{entry.fetch(:sink).id} #{entry.fetch(:sink).name}: " \
        "#{entry.fetch(:events)} events, " \
        "#{entry.fetch(:saved_views)} saved views, " \
        "#{entry.fetch(:unread_count)} unread"
    end
  end
end

class DevelopmentFeedSeeder
  EVENT_PREFIX = "dev-feed".freeze
  DEFAULT_EMAIL = "kyrylo@telesink.com".freeze
  DEFAULT_PASSWORD = "password123".freeze
  FOLDER_NAMES = [ "Product", "Systems" ].freeze
  SINK_NAMES = [
    "storefront",
    "rails requests",
    "billing webhooks",
    "ai agents",
    "ops stream",
    "support inbox"
  ].freeze

  STORE_CUSTOMERS = [
    [ "rl+demo@lemone.com", "cus_rl", "pro", "US", "180.190.12.45" ],
    [ "maya@example.test", "cus_maya", "team", "NL", "203.0.113.24" ],
    [ "oss@beagle.test", "cus_oss", "oss", "DE", "198.51.100.88" ],
    [ "jamie@example.test", "cus_jamie", "starter", "GB", "192.0.2.17" ],
    [ "nina@example.test", "cus_nina", "pro", "PH", "203.0.113.77" ]
  ].freeze

  PRODUCTS = [
    [ "telebugs.zip", "dl-telebugs", 4900 ],
    [ "incident-console", "ops-console", 2900 ],
    [ "event-retention-pack", "retention", 9900 ],
    [ "webhook-guard", "guard", 1900 ],
    [ "team-seat", "seat", 1500 ]
  ].freeze

  REQUEST_PATHS = [
    [ "GET", "/", "StoreController", "index" ],
    [ "GET", "/products", "ProductsController", "index" ],
    [ "GET", "/products/telebugs", "ProductsController", "show" ],
    [ "POST", "/cart/items", "CartItemsController", "create" ],
    [ "POST", "/checkout", "CheckoutsController", "create" ],
    [ "POST", "/webhooks/stripe", "Webhooks::StripeController", "create" ],
    [ "GET", "/account/billing", "BillingController", "show" ],
    [ "DELETE", "/cart/items/42", "CartItemsController", "destroy" ]
  ].freeze

  OPS_SERVICES = %w[api worker ingest billing notifier postgres redis].freeze
  OPS_REGIONS = %w[iad sin fra hnd].freeze

  def initialize(email: ENV.fetch("EMAIL", DEFAULT_EMAIL))
    @email = email
    @base_time = Time.current.change(usec: 0)
  end

  def call
    user = find_or_create_user
    deleted_sinks, deleted_folders = cleanup_account!(user.account)
    folders = seed_folders(user.account)

    sinks = [
      seed_sink(
        user,
        folders.fetch("Product"),
        "storefront",
        events: storefront_events,
        saved_views: [
          { name: "cart trouble", event_type: "cart_abandoned" },
          { name: "rl customer", property_key: "customer_email", property_op: "eq", property_value: "rl+demo@lemone.com" },
          { name: "large orders", property_key: "order_total_cents", property_op: "gt", property_value: "12000" },
          { name: "today", event_date: browser_today }
        ],
        unread_count: 9
      ),
      seed_sink(
        user,
        folders.fetch("Product"),
        "rails requests",
        events: request_events,
        saved_views: [
          { name: "exceptions", event_type: "exception" },
          { name: "slow requests", property_key: "duration_ms", property_op: "gt", property_value: "700" },
          { name: "local host", property_key: "host", property_op: "eq", property_value: "localhost:3000" },
          { name: "ip 180.190", property_key: "ip", property_op: "eq", property_value: "180.190.12.45" }
        ],
        unread_count: 18
      ),
      seed_sink(
        user,
        folders.fetch("Product"),
        "billing webhooks",
        events: billing_events,
        saved_views: [
          { name: "failed payments", event_type: "payment_failed" },
          { name: "stripe", property_key: "provider", property_op: "eq", property_value: "stripe" },
          { name: "large invoices", property_key: "amount_cents", property_op: "gt", property_value: "50000" },
          { name: "retry queue", property_key: "retry_count", property_op: "gt", property_value: "2" }
        ],
        unread_count: 11
      ),
      seed_sink(
        user,
        folders.fetch("Systems"),
        "ai agents",
        events: agent_events,
        saved_views: [
          { name: "approvals", event_type: "approval_requested" },
          { name: "browser work", event_type: "browser_action" },
          { name: "slow tools", property_key: "duration_ms", property_op: "gt", property_value: "45000" },
          { name: "failed runs", event_type: "agent_run_failed" }
        ],
        unread_count: 14
      ),
      seed_sink(
        user,
        folders.fetch("Systems"),
        "ops stream",
        events: ops_events,
        saved_views: [
          { name: "alerts", event_type: "alert_firing" },
          { name: "deploys", search_query: "deploy" },
          { name: "billing", property_key: "service", property_op: "eq", property_value: "billing" },
          { name: "long jobs", property_key: "duration_ms", property_op: "gt", property_value: "120000" }
        ],
        unread_count: 6
      ),
      seed_sink(
        user,
        folders.fetch("Systems"),
        "support inbox",
        events: support_events,
        saved_views: [
          { name: "urgent", property_key: "priority", property_op: "eq", property_value: "urgent" },
          { name: "enterprise", property_key: "plan", property_op: "eq", property_value: "enterprise" },
          { name: "refunds", search_query: "refund" },
          { name: "waiting", event_type: "reply_waiting" }
        ],
        unread_count: 8
      )
    ]
    user.update_columns(current_sink_id: sinks.first.fetch(:sink).id, current_folder_id: nil)

    { user: user, sinks: sinks, deleted_sinks: deleted_sinks, deleted_folders: deleted_folders }
  end

  private

  def find_or_create_user
    User.find_by(email_address: @email) ||
      User.order(:id).first ||
      begin
        account = Account.create!
        account.users.create!(
          email_address: @email,
          password: ENV.fetch("PASSWORD", DEFAULT_PASSWORD),
          role: :owner
        )
      end
  end

  def cleanup_account!(account)
    desired_folders = FOLDER_NAMES.to_set
    desired_sinks = SINK_NAMES.to_set

    deleted_sinks = account.sinks.where.not(name: desired_sinks.to_a).order(:name).pluck(:name)
    account.sinks.where.not(name: desired_sinks.to_a).destroy_all

    deleted_folders = account.folders.where.not(name: desired_folders.to_a).order(:name).pluck(:name)
    account.folders.where.not(name: desired_folders.to_a).destroy_all

    [ deleted_sinks, deleted_folders ]
  end

  def seed_folders(account)
    FOLDER_NAMES.index_with do |name|
      account.folders.find_or_create_by!(name: name)
    end
  end

  def seed_sink(user, folder, name, events:, saved_views:, unread_count:)
    sink = user.account.sinks.find_or_create_by!(name: name)
    sink.update!(folder: folder)
    membership = sink.sink_memberships.find_or_create_by!(user: user)
    prefix = "#{EVENT_PREFIX}:#{slug(name)}:"

    Event.where(sink: sink).delete_all
    sink.saved_views.where(user: user).where.not(name: saved_views.map { |view| view.fetch(:name) }).destroy_all

    rows = events.sort_by { |event| event.fetch(:occurred_at) }.each_with_index.map do |event, index|
      event_attributes(sink, event, "#{prefix}#{index.to_s.rjust(4, "0")}")
    end

    Event.insert_all!(rows) if rows.any?
    seed_saved_views(user, sink, saved_views)
    mark_membership(membership, sink, unread_count)

    {
      folder: folder,
      sink: sink,
      events: rows.size,
      saved_views: saved_views.size,
      unread_count: membership.reload.unread_count
    }
  end

  def event_attributes(sink, event, idempotency_key)
    now = Time.current
    event_type = event.fetch(:event_type)
    text = event.fetch(:text)
    properties = event.fetch(:properties)

    {
      sink_id: sink.id,
      event_type: event_type,
      emoji: event.fetch(:emoji),
      text: text,
      properties: properties,
      occurred_at: event.fetch(:occurred_at),
      idempotency_key: idempotency_key,
      sdk_name: "telesink-dev-seed",
      sdk_version: "1.0.0",
      search_text: search_text_for(event_type, text, properties),
      created_at: now,
      updated_at: now
    }
  end

  def seed_saved_views(user, sink, saved_views)
    saved_views.each do |attrs|
      saved_view = sink.saved_views.where(user: user, name: attrs.fetch(:name)).first_or_initialize
      saved_view.assign_attributes(attrs.except(:name))
      saved_view.save!
    end
  end

  def mark_membership(membership, sink, unread_count)
    cutoff = if unread_count.positive?
      sink.events.order(occurred_at: :desc, id: :desc).offset(unread_count).pick(:occurred_at)
    end

    membership.update!(
      has_unread_events: unread_count.positive?,
      unread_count: unread_count,
      last_viewed_at: cutoff || Time.current
    )
  end

  def storefront_events
    events = []

    52.times do |index|
      customer = STORE_CUSTOMERS[index % STORE_CUSTOMERS.length]
      product = PRODUCTS[(index * 2) % PRODUCTS.length]
      session_id = "sess_store_#{index.to_s.rjust(3, "0")}"
      cart_id = "cart_#{(10_000 + index).to_s(16)}"
      order_id = "ord_#{(40_000 + index).to_s(16)}"
      started_at = @base_time - (52 - index).hours * 15 - (index % 9).minutes
      quantity = (index % 3) + 1
      order_total_cents = product[2] * quantity

      events << event(
        at: started_at,
        event_type: "product_viewed",
        emoji: "\u{1F440}",
        text: "Product page viewed",
        properties: storefront_properties(customer, product, session_id).merge(
          "path" => "/products/#{product[1]}",
          "utm_source" => %w[newsletter docs github direct][index % 4]
        )
      )

      if index % 3 != 0
        events << event(
          at: started_at + (2 + index % 4).minutes,
          event_type: "add_to_cart",
          emoji: "\u{1F6D2}",
          text: "#{product[0]} added to cart",
          properties: storefront_properties(customer, product, session_id).merge(
            "cart_id" => cart_id,
            "quantity" => quantity,
            "cart_total_cents" => order_total_cents
          )
        )
      end

      if index % 4 != 0
        events << event(
          at: started_at + (7 + index % 5).minutes,
          event_type: "checkout_started",
          emoji: "\u{1F9FE}",
          text: "Checkout started",
          properties: storefront_properties(customer, product, session_id).merge(
            "cart_id" => cart_id,
            "step" => %w[email shipping payment][index % 3],
            "order_total_cents" => order_total_cents
          )
        )
      end

      if index % 5 == 0
        events << event(
          at: started_at + (18 + index % 4).minutes,
          event_type: "cart_abandoned",
          emoji: "\u{1F6D1}",
          text: "Cart abandoned during checkout",
          properties: storefront_properties(customer, product, session_id).merge(
            "cart_id" => cart_id,
            "order_total_cents" => order_total_cents,
            "reason" => %w[payment_declined closed_tab shipping_cost][index % 3]
          )
        )
      elsif index % 4 != 0
        events << event(
          at: started_at + (13 + index % 6).minutes,
          event_type: "payment_authorized",
          emoji: "\u2705",
          text: "Payment authorized",
          properties: storefront_properties(customer, product, session_id).merge(
            "cart_id" => cart_id,
            "payment_provider" => %w[stripe paddle manual][index % 3],
            "order_total_cents" => order_total_cents
          )
        )

        events << event(
          at: started_at + (15 + index % 6).minutes,
          event_type: "order_created",
          emoji: "\u{1F4E6}",
          text: "Order #{order_id} created",
          properties: storefront_properties(customer, product, session_id).merge(
            "order_id" => order_id,
            "cart_id" => cart_id,
            "order_total_cents" => order_total_cents
          )
        )

        events << event(
          at: started_at + (17 + index % 8).minutes,
          event_type: "email_delivered",
          emoji: "\u2709\uFE0F",
          text: "Receipt email delivered",
          properties: storefront_properties(customer, product, session_id).merge(
            "order_id" => order_id,
            "message_id" => "msg_#{(90_000 + index).to_s(16)}",
            "template" => "receipt"
          )
        )
      end

      if index % 17 == 0
        events << event(
          at: started_at + 2.hours,
          event_type: "refund_created",
          emoji: "\u{1F501}",
          text: "Refund created",
          properties: storefront_properties(customer, product, session_id).merge(
            "order_id" => order_id,
            "refund_cents" => product[2],
            "reason" => "duplicate_purchase"
          )
        )
      end

      next unless index % 11 == 0

      events << event(
        at: started_at + 3.hours,
        event_type: "inventory_low",
        emoji: "\u26A0\uFE0F",
        text: "Inventory threshold reached",
        properties: {
          "product_sku" => product[1],
          "remaining" => 3 + index % 8,
          "warehouse" => %w[eu-1 us-2 apac-1][index % 3]
        }
      )
    end

    events
  end

  def request_events
    events = []

    88.times do |index|
      method, path, controller, action = REQUEST_PATHS[index % REQUEST_PATHS.length]
      customer = STORE_CUSTOMERS[(index * 3) % STORE_CUSTOMERS.length]
      started_at = @base_time - (88 - index).minutes * 7
      request_id = "req_#{SecureRandom.hex(6)}_#{index.to_s.rjust(3, "0")}"
      status = request_status(index)
      duration_ms = request_duration(index, status)
      db_ms = (duration_ms * (0.18 + (index % 5) * 0.04)).round(1)
      view_ms = (duration_ms * (0.25 + (index % 4) * 0.03)).round(1)
      base_props = {
        "request_id" => request_id,
        "method" => method,
        "host" => "localhost:3000",
        "path" => path,
        "controller" => controller,
        "action" => action,
        "ip" => customer[4],
        "customer_email" => customer[0],
        "params" => request_params(index),
        "user_agent" => user_agent(index)
      }

      events << event(
        at: started_at,
        event_type: method,
        emoji: status_emoji(status),
        text: "#{path} -> #{status}",
        properties: base_props.merge(
          "status" => status,
          "duration_ms" => duration_ms,
          "db_ms" => db_ms,
          "view_ms" => view_ms
        )
      )

      if db_ms > 90
        events << event(
          at: started_at + 0.3.seconds,
          event_type: "SQL",
          emoji: "\u{1F40C}",
          text: "Slow query in #{controller}##{action}",
          properties: base_props.merge(
            "duration_ms" => db_ms,
            "sql" => "SELECT * FROM events WHERE sink_id = $1 ORDER BY occurred_at DESC LIMIT $2"
          )
        )
      end

      if status >= 500
        events << event(
          at: started_at + 0.7.seconds,
          event_type: "exception",
          emoji: "\u{1F525}",
          text: "Unhandled exception",
          properties: base_props.merge(
            "status" => status,
            "error_class" => %w[NoMethodError Timeout::Error PG::ConnectionBad][index % 3],
            "duration_ms" => duration_ms,
            "trace_id" => "trace_#{index.to_s(16)}"
          )
        )
      else
        events << event(
          at: started_at + 0.8.seconds,
          event_type: "render",
          emoji: "\u{1F5BC}\uFE0F",
          text: "#{controller}##{action} rendered",
          properties: base_props.merge(
            "status" => status,
            "duration_ms" => view_ms,
            "template" => "#{controller.delete_suffix("Controller").underscore}/#{action}"
          )
        )
      end

      next unless index % 9 == 0

      events << event(
        at: started_at + 2.seconds,
        event_type: "job",
        emoji: "\u{1F9F0}",
        text: "Enqueued follow-up job",
        properties: base_props.merge(
          "job_class" => %w[ReceiptJob WebhookDeliveryJob SearchIndexJob][index % 3],
          "queue" => %w[default mailers events][index % 3],
          "duration_ms" => 12 + index
        )
      )
    end

    events
  end

  def billing_events
    providers = %w[stripe paddle manual]
    events = []

    70.times do |index|
      customer = STORE_CUSTOMERS[(index * 2) % STORE_CUSTOMERS.length]
      provider = providers[index % providers.length]
      invoice_id = "inv_#{(60_000 + index).to_s(16)}"
      subscription_id = "sub_#{(30_000 + index / 2).to_s(16)}"
      amount_cents = PRODUCTS[index % PRODUCTS.length][2] * (1 + index % 6)
      started_at = @base_time - (70 - index).hours * 9 - (index % 13).minutes
      base_props = {
        "provider" => provider,
        "customer_email" => customer[0],
        "customer_id" => customer[1],
        "plan" => customer[2],
        "country" => customer[3],
        "invoice_id" => invoice_id,
        "subscription_id" => subscription_id,
        "amount_cents" => amount_cents,
        "webhook_id" => "wh_#{SecureRandom.hex(5)}"
      }

      events << event(
        at: started_at,
        event_type: "invoice_created",
        emoji: "\u{1F9FE}",
        text: "Invoice created",
        properties: base_props.merge(
          "billing_reason" => %w[subscription_cycle upgrade manual][index % 3]
        )
      )

      if index % 6 == 0
        events << event(
          at: started_at + 3.minutes,
          event_type: "payment_failed",
          emoji: "\u26A0\uFE0F",
          text: "Payment failed",
          properties: base_props.merge(
            "failure_code" => %w[card_declined insufficient_funds expired_card][index % 3],
            "retry_count" => 1 + index % 5
          )
        )

        events << event(
          at: started_at + 16.minutes,
          event_type: "retry_scheduled",
          emoji: "\u{1F501}",
          text: "Payment retry scheduled",
          properties: base_props.merge(
            "retry_count" => 2 + index % 5,
            "retry_at" => (started_at + 1.day).iso8601
          )
        )
      else
        events << event(
          at: started_at + 4.minutes,
          event_type: "payment_succeeded",
          emoji: "\u2705",
          text: "Payment succeeded",
          properties: base_props.merge(
            "receipt_url" => "https://billing.example.test/#{invoice_id}"
          )
        )
      end

      next unless index % 10 == 0

      events << event(
        at: started_at + 30.minutes,
        event_type: "subscription_updated",
        emoji: "\u{1F4C8}",
        text: "Subscription changed",
        properties: base_props.merge(
          "old_plan" => customer[2],
          "new_plan" => %w[team pro enterprise][index % 3],
          "seat_count" => 3 + index % 18
        )
      )
    end

    events
  end

  def agent_events
    agents = [
      [ "researcher", "browser", "gpt-5" ],
      [ "builder", "shell", "gpt-5-codex" ],
      [ "reviewer", "diff", "gpt-5" ],
      [ "support-triage", "crm", "gpt-5-mini" ]
    ].freeze
    goals = [
      "Investigate checkout dropoff",
      "Patch webhook retry handling",
      "Summarize incident timeline",
      "Draft migration notes",
      "Classify support backlog",
      "Tune saved view filters"
    ].freeze
    tools = %w[browser.search browser.open shell.exec git.diff rails.runner db.query].freeze
    events = []

    54.times do |index|
      agent_name, primary_tool, model = agents[index % agents.length]
      goal = goals[index % goals.length]
      run_id = "agent_run_#{(20_000 + index).to_s(16)}"
      trace_id = "agent_trace_#{SecureRandom.hex(5)}"
      started_at = @base_time - (54 - index).hours * 11 - (index % 17).minutes
      base_props = {
        "agent" => agent_name,
        "model" => model,
        "run_id" => run_id,
        "trace_id" => trace_id,
        "goal" => goal,
        "workspace" => "telesink",
        "turn" => index + 1
      }

      events << event(
        at: started_at,
        event_type: "agent_run_started",
        emoji: "\u{1F9E0}",
        text: goal,
        properties: base_props.merge(
          "temperature" => [ 0.1, 0.2, 0.4 ][index % 3],
          "input_tokens" => 1_200 + index * 37
        )
      )

      events << event(
        at: started_at + (2 + index % 4).minutes,
        event_type: "plan_updated",
        emoji: "\u{1F4DD}",
        text: "Plan updated",
        properties: base_props.merge(
          "steps" => 3 + index % 5,
          "current_step" => %w[inspect implement verify summarize][index % 4]
        )
      )

      events << event(
        at: started_at + (5 + index % 7).minutes,
        event_type: "tool_called",
        emoji: "\u{1F6E0}\uFE0F",
        text: "#{tools[index % tools.length]} called",
        properties: base_props.merge(
          "tool" => tools[index % tools.length],
          "primary_tool" => primary_tool,
          "duration_ms" => 2_000 + (index * 1_777) % 70_000,
          "cache_hit" => index % 4 == 0
        )
      )

      if index % 5 == 0
        events << event(
          at: started_at + (9 + index % 6).minutes,
          event_type: "browser_action",
          emoji: "\u{1F50D}",
          text: "Browser verification step",
          properties: base_props.merge(
            "url" => "http://127.0.0.1:3000/sinks/#{200 + index}",
            "action" => %w[open click scroll inspect][index % 4],
            "viewport" => %w[desktop mobile][index % 2]
          )
        )
      end

      if index % 7 == 0
        events << event(
          at: started_at + 11.minutes,
          event_type: "approval_requested",
          emoji: "\u{1F6A6}",
          text: "Approval requested",
          properties: base_props.merge(
            "reason" => %w[database_write destructive_cleanup network_access][index % 3],
            "resource" => %w[development_db local_branch browser_session][index % 3]
          )
        )
      end

      if index % 6 == 0
        events << event(
          at: started_at + 13.minutes,
          event_type: "memory_retrieved",
          emoji: "\u{1F4DA}",
          text: "Relevant project memory retrieved",
          properties: base_props.merge(
            "memory_key" => %w[ui_principles seed_policy live_feed_notes][index % 3],
            "score" => (0.74 + (index % 20) / 100.0).round(2)
          )
        )
      end

      if index % 8 == 0
        events << event(
          at: started_at + 18.minutes,
          event_type: "code_patch_created",
          emoji: "\u{1F9E9}",
          text: "Patch created",
          properties: base_props.merge(
            "files_changed" => 1 + index % 9,
            "insertions" => 20 + index * 3,
            "deletions" => 4 + index % 17
          )
        )
      end

      if index % 13 == 0
        events << event(
          at: started_at + 22.minutes,
          event_type: "agent_run_failed",
          emoji: "\u{1F525}",
          text: "Agent run failed",
          properties: base_props.merge(
            "error_class" => %w[ToolTimeout ValidationError PermissionDenied][index % 3],
            "duration_ms" => 180_000 + index * 2_000
          )
        )
      else
        events << event(
          at: started_at + 24.minutes,
          event_type: "evaluation_passed",
          emoji: "\u2705",
          text: "Evaluation passed",
          properties: base_props.merge(
            "checks" => 3 + index % 8,
            "duration_ms" => 40_000 + index * 1_000
          )
        )

        events << event(
          at: started_at + 26.minutes,
          event_type: "agent_run_completed",
          emoji: "\u{1F3C1}",
          text: "Agent run completed",
          properties: base_props.merge(
            "output_tokens" => 600 + index * 23,
            "duration_ms" => 55_000 + index * 1_500
          )
        )
      end

      next unless index % 16 == 0

      events << event(
        at: started_at + 35.minutes,
        event_type: "handoff_created",
        emoji: "\u{1F91D}",
        text: "Handoff created",
        properties: base_props.merge(
          "target_agent" => agents[(index + 1) % agents.length][0],
          "handoff_reason" => "specialized review"
        )
      )
    end

    events
  end

  def ops_events
    events = []

    64.times do |index|
      service = OPS_SERVICES[index % OPS_SERVICES.length]
      region = OPS_REGIONS[(index * 2) % OPS_REGIONS.length]
      started_at = @base_time - (64 - index).hours * 17
      run_id = "run_#{(50_000 + index).to_s(16)}"
      commit = SecureRandom.hex(4)

      events << event(
        at: started_at,
        event_type: "deploy_started",
        emoji: "\u{1F680}",
        text: "Deploy started for #{service}",
        properties: {
          "service" => service,
          "env" => "development",
          "region" => region,
          "run_id" => run_id,
          "commit" => commit,
          "operator" => %w[kyrylo bot release][index % 3]
        }
      )

      if index % 7 == 0
        events << event(
          at: started_at + 6.minutes,
          event_type: "alert_firing",
          emoji: "\u{1F6A8}",
          text: "Error budget burn alert",
          properties: {
            "service" => service,
            "env" => "development",
            "region" => region,
            "severity" => %w[warning critical][index % 2],
            "error_rate" => (1.5 + index % 6).round(2),
            "trace_id" => "ops_trace_#{index.to_s(16)}"
          }
        )
      end

      if index % 10 == 0
        events << event(
          at: started_at + 12.minutes,
          event_type: "incident_opened",
          emoji: "\u26A1",
          text: "Incident opened",
          properties: {
            "service" => service,
            "region" => region,
            "severity" => "critical",
            "incident_id" => "inc_#{(700 + index).to_s(16)}",
            "summary" => "Webhook delivery latency above threshold"
          }
        )
      end

      events << event(
        at: started_at + (14 + index % 11).minutes,
        event_type: "deploy_finished",
        emoji: "\u2705",
        text: "Deploy finished for #{service}",
        properties: {
          "service" => service,
          "env" => "development",
          "region" => region,
          "run_id" => run_id,
          "commit" => commit,
          "duration_ms" => 45_000 + index * 1_337,
          "status" => index % 13 == 0 ? "rolled_back" : "ok"
        }
      )

      next unless index % 4 == 0

      events << event(
        at: started_at + 40.minutes,
        event_type: "worker_retry",
        emoji: "\u{1F501}",
        text: "Worker retry scheduled",
        properties: {
          "service" => service,
          "queue" => %w[events mailers webhooks default][index % 4],
          "attempt" => 1 + index % 5,
          "duration_ms" => 30_000 + index * 2_000,
          "job_id" => "job_#{SecureRandom.hex(5)}"
        }
      )
    end

    18.times do |index|
      events << event(
        at: @base_time - index.days - 2.hours,
        event_type: index.even? ? "backup_completed" : "feature_flag_changed",
        emoji: index.even? ? "\u{1F4BE}" : "\u{1F6A9}",
        text: index.even? ? "Database backup completed" : "Feature flag changed",
        properties: {
          "service" => index.even? ? "postgres" : "api",
          "env" => "development",
          "region" => OPS_REGIONS[index % OPS_REGIONS.length],
          "duration_ms" => 80_000 + index * 3_500,
          "flag" => index.even? ? nil : %w[new_feed live_status property_filters][index % 3]
        }.compact
      )
    end

    events
  end

  def support_events
    subjects = [
      "refund request",
      "webhook retry question",
      "cannot find receipt",
      "team invite failed",
      "agent generated wrong summary",
      "billing address update"
    ].freeze
    channels = %w[email chat slack].freeze
    priorities = %w[normal normal high urgent].freeze
    events = []

    58.times do |index|
      customer = STORE_CUSTOMERS[(index * 4) % STORE_CUSTOMERS.length]
      ticket_id = "tic_#{(80_000 + index).to_s(16)}"
      subject = subjects[index % subjects.length]
      started_at = @base_time - (58 - index).hours * 10 - (index % 19).minutes
      base_props = {
        "ticket_id" => ticket_id,
        "customer_email" => customer[0],
        "customer_id" => customer[1],
        "plan" => index % 9 == 0 ? "enterprise" : customer[2],
        "country" => customer[3],
        "channel" => channels[index % channels.length],
        "priority" => priorities[index % priorities.length],
        "assignee" => %w[ana max sam bot][index % 4],
        "subject" => subject
      }

      events << event(
        at: started_at,
        event_type: "ticket_created",
        emoji: "\u{1F39F}\uFE0F",
        text: "Ticket created",
        properties: base_props.merge(
          "first_response_sla_minutes" => [ 15, 60, 240 ][index % 3]
        )
      )

      if index % 4 == 0
        events << event(
          at: started_at + 9.minutes,
          event_type: "triage_completed",
          emoji: "\u{1F9ED}",
          text: "Triage completed",
          properties: base_props.merge(
            "category" => %w[billing integration product ai_agent][index % 4],
            "sentiment" => %w[neutral frustrated happy][index % 3]
          )
        )
      end

      if index % 6 == 0
        events << event(
          at: started_at + 17.minutes,
          event_type: "reply_waiting",
          emoji: "\u23F3",
          text: "Waiting for customer reply",
          properties: base_props.merge(
            "waiting_hours" => 2 + index % 26,
            "last_message_from" => "support"
          )
        )
      else
        events << event(
          at: started_at + 22.minutes,
          event_type: "agent_replied",
          emoji: "\u{1F4AC}",
          text: "Support reply sent",
          properties: base_props.merge(
            "reply_id" => "reply_#{SecureRandom.hex(5)}",
            "macro" => %w[refund_instructions webhook_docs invite_reset][index % 3]
          )
        )
      end

      next unless index % 11 == 0

      events << event(
        at: started_at + 1.hour,
        event_type: "ticket_escalated",
        emoji: "\u{1F6A8}",
        text: "Ticket escalated",
        properties: base_props.merge(
          "team" => %w[engineering billing success][index % 3],
          "reason" => %w[bug vip_customer data_question][index % 3]
        )
      )
    end

    events
  end

  def storefront_properties(customer, product, session_id)
    {
      "customer_email" => customer[0],
      "customer_id" => customer[1],
      "plan" => customer[2],
      "country" => customer[3],
      "ip" => customer[4],
      "session_id" => session_id,
      "file" => product[0],
      "product_sku" => product[1],
      "price_cents" => product[2]
    }
  end

  def request_status(index)
    return 500 if (index % 23).zero?
    return 404 if (index % 17).zero?
    return 302 if (index % 11).zero?

    200
  end

  def request_duration(index, status)
    base = 40 + (index * 37) % 900
    status >= 500 ? base + 900 : base
  end

  def status_emoji(status)
    return "\u{1F525}" if status >= 500
    return "\u26A0\uFE0F" if status >= 400
    return "\u21AA\uFE0F" if status >= 300

    "\u2705"
  end

  def request_params(index)
    {
      "page" => 1 + index % 5,
      "q" => %w[events telebugs billing empty][index % 4],
      "debug" => index % 13 == 0
    }
  end

  def user_agent(index)
    agents = [
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/134.0",
      "curl/8.7.1",
      "TelesinkSDK/1.2.3 Ruby",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) Mobile Safari/604.1"
    ]

    agents[index % agents.length]
  end

  def event(at:, event_type:, emoji:, text:, properties:)
    {
      occurred_at: at,
      event_type: event_type,
      emoji: emoji,
      text: text,
      properties: properties
    }
  end

  def search_text_for(event_type, text, properties)
    parts = [ event_type, text ]
    properties.each do |key, value|
      parts << key
      parts << (value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value.to_s)
    end

    parts.compact.join(" ").squish
  end

  def slug(name)
    name.parameterize(separator: "-")
  end

  def browser_today
    Time.zone.today
  end
end
