-- Create Tables
DROP TABLE IF EXISTS message_emote, stream_category, notification, subscription, message, chat, stream, category, emote, channel, "user" CASCADE;

CREATE TABLE category (
    category_id SERIAL PRIMARY KEY,
    type VARCHAR(100),
    name VARCHAR(255)
);

CREATE TABLE "user" (
    user_id SERIAL PRIMARY KEY,
    channel_id INT,
    username VARCHAR(50)
);

CREATE TABLE channel (
    channel_id SERIAL PRIMARY KEY,
    subscriber_count INT,
    is_live BOOLEAN
);

CREATE TABLE chat (
    chat_id SERIAL PRIMARY KEY,
    stream_id INT
);

CREATE TABLE stream (
    stream_id SERIAL PRIMARY KEY,
    channel_id INT,
    title VARCHAR(255),
    view_count INT,
    duration TIME,
    date TIMESTAMPTZ,
    chat_id INT
);

CREATE TABLE message (
    message_id SERIAL PRIMARY KEY,
    user_id INT,
    chat_id INT,
    text TEXT,
    send_time TIMESTAMPTZ
);

CREATE TABLE subscription (
    subscription_id SERIAL PRIMARY KEY,
    user_id INT,
    channel_id INT,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    tier INT,
    cost DECIMAL(10, 2)
);

CREATE TABLE notification (
    notification_id SERIAL PRIMARY KEY,
    channel_id INT,
    user_id INT,
    message TEXT
);

CREATE TABLE emote (
    emote_id SERIAL PRIMARY KEY,
    user_id INT
);

CREATE TABLE stream_category (
    stream_id INT,
    category_id INT,
    PRIMARY KEY (stream_id, category_id)
);

CREATE TABLE message_emote (
    message_id INT,
    emote_id INT,
    PRIMARY KEY (message_id, emote_id)
);

-----------------------------------------------------------------------------------------------

-- Add foreign key constraints
ALTER TABLE "user"
ADD CONSTRAINT fk_user_channel FOREIGN KEY (channel_id) REFERENCES channel(channel_id);

ALTER TABLE stream
ADD CONSTRAINT fk_stream_channel FOREIGN KEY (channel_id) REFERENCES channel(channel_id);

ALTER TABLE stream
ADD CONSTRAINT fk_stream_chat FOREIGN KEY (chat_id) REFERENCES chat(chat_id);

ALTER TABLE chat
ADD CONSTRAINT fk_chat_stream FOREIGN KEY (stream_id) REFERENCES stream(stream_id);

ALTER TABLE message
ADD CONSTRAINT fk_message_user FOREIGN KEY (user_id) REFERENCES "user"(user_id);

ALTER TABLE message
ADD CONSTRAINT fk_message_chat FOREIGN KEY (chat_id) REFERENCES chat(chat_id);

ALTER TABLE subscription
ADD CONSTRAINT fk_subscription_user FOREIGN KEY (user_id) REFERENCES "user"(user_id);

ALTER TABLE subscription
ADD CONSTRAINT fk_subscription_channel FOREIGN KEY (channel_id) REFERENCES channel(channel_id);

ALTER TABLE notification
ADD CONSTRAINT fk_notification_channel FOREIGN KEY (channel_id) REFERENCES channel(channel_id);

ALTER TABLE notification
ADD CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES "user"(user_id);

ALTER TABLE emote
ADD CONSTRAINT fk_emote_user FOREIGN KEY (user_id) REFERENCES "user"(user_id);

ALTER TABLE stream_category
ADD CONSTRAINT fk_stream_category_stream FOREIGN KEY (stream_id) REFERENCES stream(stream_id),
ADD CONSTRAINT fk_stream_category_category FOREIGN KEY (category_id) REFERENCES category(category_id);

ALTER TABLE message_emote
ADD CONSTRAINT fk_message_emote_message FOREIGN KEY (message_id) REFERENCES message(message_id),
ADD CONSTRAINT fk_message_emote_emote FOREIGN KEY (emote_id) REFERENCES emote(emote_id);

-----------------------------------------------------------------------------------------------

-- Insert data
INSERT INTO category (type, name) 
VALUES ('Game', 'Fortnite'),
       ('Game', 'League of Legends'),
       ('Talk Show', 'Just Chatting');

INSERT INTO channel (subscriber_count, is_live)
VALUES (1000, TRUE),
       (500, FALSE),
       (300, TRUE);

INSERT INTO "user" (channel_id, username)
VALUES (1, 'StreamerOne'),
       (2, 'ViewerOne'),
       (3, 'ModeratorOne');

INSERT INTO stream (channel_id, title, view_count, duration, date)
VALUES (1, 'Fortnite Pro Gameplay', 15000, '02:30:00', '2024-10-17 18:00:00'),
       (2, 'LoL Strategy Tips', 7500, '01:45:00', '2024-10-16 14:00:00'),
       (3, 'Casual Chatting', 20000, '03:00:00', '2024-10-15 20:30:00');

INSERT INTO chat (stream_id)
VALUES (1),
       (2),
       (3);

INSERT INTO message (user_id, chat_id, text, send_time)
VALUES (2, 1, 'Great stream!', '2024-10-17 18:05:00'),
       (1, 2, 'Thanks for the tips!', '2024-10-16 14:05:00'),
       (3, 3, 'Just chilling!', '2024-10-15 20:35:00');

INSERT INTO subscription (user_id, channel_id, start_date, end_date, tier, cost)
VALUES (2, 1, '2024-10-01 12:00:00', '2024-11-01 12:00:00', 1, 4.99),
       (3, 1, '2024-09-20 12:00:00', '2024-10-20 12:00:00', 2, 9.99),
       (1, 3, '2024-08-15 12:00:00', '2024-09-15 12:00:00', 1, 4.99);

INSERT INTO notification (channel_id, user_id, message)
VALUES (1, 2, 'StreamerOne just went live!'),
       (2, 3, 'ViewerOne sent a message!'),
       (3, 1, 'ModeratorOne sent a message!');

INSERT INTO emote (user_id)
VALUES (1),
       (2),
       (3);

INSERT INTO stream_category (stream_id, category_id)
VALUES (1, 1),
       (2, 2),
       (3, 3);

INSERT INTO message_emote (message_id, emote_id)
VALUES (1, 1),
       (2, 2),
       (3, 3);

-------------------------------------------------------------------------------------------

-- Attach the trigger to the channel table
CREATE TRIGGER notify_users_after_channel_live_update
AFTER UPDATE OF is_live ON channel
FOR EACH ROW
WHEN (NEW.is_live IS TRUE)
EXECUTE FUNCTION trigger_notify_users_on_live();

CREATE OR REPLACE FUNCTION trigger_notify_users_on_live()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only trigger the notification if the channel is_live value is set to TRUE
    IF NEW.is_live = TRUE THEN
        CALL notify_users_on_live_channel(NEW.channel_id);
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE PROCEDURE notify_users_on_live_channel(p_channel_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert notifications for all users subscribed to the channel that just went live
    INSERT INTO notification (channel_id, user_id, message)
    SELECT s.channel_id, s.user_id, 'Channel ' || c.channel_id || ' is now live!'
    FROM subscription s
    JOIN channel c ON s.channel_id = c.channel_id
    WHERE c.channel_id = p_channel_id AND c.is_live = TRUE;

END;
$$;

-- Update is_live flag to trigger notification

UPDATE channel
SET is_live = FALSE
WHERE channel_id = 1;

UPDATE channel
SET is_live = TRUE
WHERE channel_id = 1;

select * from notification;

-------------------------------------------------------------------


CREATE OR REPLACE FUNCTION trigger_notify_user_on_subscription_end()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if the subscription end date is reached or updated to a past date
    IF NEW.end_date <= NOW() THEN
        -- Call the procedure to notify the user
        CALL notify_user_on_subscription_end(NEW.user_id, NEW.channel_id);
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER notify_user_after_subscription_end
AFTER UPDATE OF end_date ON subscription
FOR EACH ROW
EXECUTE FUNCTION trigger_notify_user_on_subscription_end();


CREATE OR REPLACE PROCEDURE notify_user_on_subscription_end(p_user_id INT, p_channel_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert notification for the user when the subscription ends
    INSERT INTO notification (channel_id, user_id, message)
    VALUES (p_channel_id, p_user_id, 'Your subscription to channel ' || p_channel_id || ' has ended.');
END;
$$;

-- Update a subscription's end date to simulate it ending
UPDATE subscription
SET end_date = '2024-11-01 10:00:00'
WHERE subscription_id = 1;

UPDATE subscription
SET end_date = NOW()
WHERE subscription_id = 1;

select * from notification;
