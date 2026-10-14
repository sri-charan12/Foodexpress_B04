-- =====================================================
-- FILE 1: CREATE TABLES  (run first, only once)
-- WARNING: DROP TABLE deletes existing tables and their data.
-- =====================================================
DROP VIEW IF EXISTS v_order_summary;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS deliveries;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS menu_categories;
DROP TABLE IF EXISTS delivery_agents;
DROP TABLE IF EXISTS restaurants;
DROP TABLE IF EXISTS customers;


CREATE TABLE restaurants (
    restaurant_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_name VARCHAR(150) NOT NULL,
    cuisine_type    VARCHAR(50)  NOT NULL,
    city            VARCHAR(100) NOT NULL,
    email           VARCHAR(150) UNIQUE NOT NULL,
    phone           VARCHAR(15)  NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customers (
    customer_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email         VARCHAR(150) UNIQUE NOT NULL,
    phone         VARCHAR(15)  NOT NULL,
    address       VARCHAR(200),
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE delivery_agents (
    agent_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agent_name   VARCHAR(100) NOT NULL,
    phone        VARCHAR(15) UNIQUE NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL
        CHECK (vehicle_type IN ('BIKE','SCOOTER','BICYCLE','CAR')),
    is_available BOOLEAN DEFAULT TRUE
);

CREATE TABLE menu_categories (
    category_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id BIGINT NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    CONSTRAINT fk_category_restaurant
        FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    CONSTRAINT uq_restaurant_category UNIQUE (restaurant_id, category_name)
);

CREATE TABLE menu_items (
    item_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id BIGINT NOT NULL,
    category_id   BIGINT NOT NULL,
    item_name     VARCHAR(150) NOT NULL,
    price         NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    is_available  BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_item_restaurant
        FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    CONSTRAINT fk_item_category
        FOREIGN KEY (category_id) REFERENCES menu_categories(category_id),
    CONSTRAINT uq_restaurant_item UNIQUE (restaurant_id, item_name)
);

CREATE TABLE orders (
    order_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id        BIGINT NOT NULL,
    restaurant_id      BIGINT NOT NULL,
    delivery_agent_id  BIGINT,
    order_date         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    order_status       VARCHAR(20) DEFAULT 'PLACED',
    CONSTRAINT fk_order_customer   FOREIGN KEY (customer_id)       REFERENCES customers(customer_id),
    CONSTRAINT fk_order_restaurant FOREIGN KEY (restaurant_id)     REFERENCES restaurants(restaurant_id),
    CONSTRAINT fk_order_agent      FOREIGN KEY (delivery_agent_id) REFERENCES delivery_agents(agent_id),
    CONSTRAINT chk_order_status
        CHECK (order_status IN ('PLACED','PREPARING','OUT_FOR_DELIVERY','DELIVERED','CANCELLED'))
);

CREATE TABLE order_items (
    order_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      BIGINT NOT NULL,
    item_id       BIGINT NOT NULL,
    quantity      INTEGER NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    CONSTRAINT fk_orderitem_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_orderitem_item  FOREIGN KEY (item_id)  REFERENCES menu_items(item_id),
    CONSTRAINT uq_order_item UNIQUE (order_id, item_id)
);

CREATE TABLE payments (
    payment_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id       BIGINT NOT NULL UNIQUE,
    amount         NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    payment_method VARCHAR(20) NOT NULL
        CHECK (payment_method IN ('CARD','UPI','CASH','WALLET')),
    payment_status VARCHAR(20) DEFAULT 'PENDING'
        CHECK (payment_status IN ('PENDING','SUCCESS','FAILED','REFUNDED')),
    payment_date   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

CREATE TABLE deliveries (
    delivery_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        BIGINT NOT NULL UNIQUE,
    agent_id        BIGINT NOT NULL,
    pickup_time     TIMESTAMP,
    delivery_time   TIMESTAMP,
    delivery_status VARCHAR(20) DEFAULT 'ASSIGNED'
        CHECK (delivery_status IN ('ASSIGNED','PICKED_UP','DELIVERED','FAILED')),
    CONSTRAINT fk_delivery_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_delivery_agent FOREIGN KEY (agent_id) REFERENCES delivery_agents(agent_id)
);

-- reviews now live in MongoDB (collection food_express_mongo.reviews)
