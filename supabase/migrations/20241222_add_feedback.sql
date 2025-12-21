-- Add feedback column to chat_messages
alter table chat_messages add column if not exists feedback_rating int default 0; -- 1: like, -1: dislike, 0: none

-- Policy to allow users to update their own messages (for feedback)
-- (Already exists "Users can update own messages" ? No, I only added view and insert before)
-- Let's check previous migration.
-- "create policy "Users can view own messages" ..."
-- "create policy "Users can insert own messages" ..."
-- Missing update policy for messages.

create policy "Users can update own messages" 
  on chat_messages for update 
  using (auth.uid() = user_id);
