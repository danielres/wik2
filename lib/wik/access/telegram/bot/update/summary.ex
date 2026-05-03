defmodule Wik.Access.Telegram.Bot.Update.Summary do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :actor_name, :string do
      allow_nil? true
    end

    attribute :actor_username, :string do
      allow_nil? true
    end

    attribute :chat_id, :string do
      allow_nil? true
    end

    attribute :chat_title, :string do
      allow_nil? true
    end

    attribute :chat_type, :string do
      allow_nil? true
    end

    attribute :message_text, :string do
      allow_nil? true
    end

    attribute :status_from, :string do
      allow_nil? true
    end

    attribute :status_to, :string do
      allow_nil? true
    end

    attribute :update_type, :string do
      allow_nil? false
    end
  end
end
