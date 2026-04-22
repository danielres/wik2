#!/usr/bin/env bash

# Setup the Telegram bot webhook url
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -d "url=https://$DEV_HOST/webhooks/telegram" \
  -d 'allowed_updates=["my_chat_member","message","channel_post"]'
