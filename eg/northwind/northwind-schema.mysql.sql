SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

DROP SCHEMA IF EXISTS `northwind` ;
CREATE SCHEMA IF NOT EXISTS `northwind` DEFAULT CHARACTER SET latin1 ;
USE `northwind` ;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE categories (
    category_id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(15) NOT NULL,
    description TEXT,
    picture LONGBLOB
);


--
-- Name: customer_customer_demo; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE customer_customer_demo (
    customer_id VARCHAR(5) NOT NULL,
    customer_type_id VARCHAR(10) NOT NULL,
    PRIMARY KEY ( customer_id, customer_type_id )
);


--
-- Name: customer_demographics; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE customer_demographics (
    customer_type_id VARCHAR(10) NOT NULL PRIMARY KEY,
    customer_desc text
);


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE customers (
    customer_id VARCHAR(10) NOT NULL PRIMARY KEY,
    company_name VARCHAR(40) NOT NULL,
    contact_name VARCHAR(30),
    contact_title VARCHAR(30),
    address VARCHAR(60),
    city VARCHAR(15),
    region VARCHAR(15),
    postal_code VARCHAR(10),
    country VARCHAR(15),
    phone VARCHAR(24),
    fax VARCHAR(24)
);


--
-- Name: employees; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE employees (
    employee_id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
    last_name VARCHAR(20) NOT NULL,
    first_name VARCHAR(10) NOT NULL,
    title VARCHAR(30),
    title_of_courtesy VARCHAR(25),
    birth_date DATE,
    hire_date DATE,
    address VARCHAR(60),
    city VARCHAR(15),
    region VARCHAR(15),
    postal_code VARCHAR(10),
    country VARCHAR(15),
    home_phone VARCHAR(24),
    extension VARCHAR(4),
    photo LONGBLOB,
    notes TEXT,
    reports_to INTEGER,
    photo_path VARCHAR(255),
    CONSTRAINT FOREIGN KEY (reports_to)
        REFERENCES employees ( employee_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);


--
-- Name: employee_territories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE employee_territories (
    employee_id INTEGER NOT NULL,
    territory_id VARCHAR(20) NOT NULL,
    PRIMARY KEY ( employee_id, territory_id ),
    CONSTRAINT FOREIGN KEY (employee_id)
        REFERENCES employees ( employee_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FOREIGN KEY (territory_id)
        REFERENCES territories ( territory_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);




--
-- Name: order_details; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE order_details (
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    unit_price DECIMAL(13,2) NOT NULL,
    quantity INTEGER NOT NULL,
    discount DECIMAL(13,2) NOT NULL,
    PRIMARY KEY ( order_id, product_id ),
    CONSTRAINT FOREIGN KEY (order_id)
        REFERENCES orders ( order_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FOREIGN KEY (product_id)
        REFERENCES products ( product_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE orders (
    order_id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    customer_id VARCHAR(5),
    employee_id INTEGER,
    order_date DATE,
    required_date DATE,
    shipped_date DATE,
    ship_via INTEGER,
    freight DECIMAL(13,2),
    ship_name VARCHAR(40),
    ship_address VARCHAR(60),
    ship_city VARCHAR(15),
    ship_region VARCHAR(15),
    ship_postal_code VARCHAR(10),
    ship_country VARCHAR(15),
    CONSTRAINT FOREIGN KEY (customer_id)
        REFERENCES customers ( customer_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FOREIGN KEY (employee_id)
        REFERENCES employees ( employee_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);


--
-- Name: products; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE products (
    product_id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(40) NOT NULL,
    supplier_id INTEGER,
    category_id INTEGER,
    quantity_per_unit VARCHAR(20),
    unit_price DECIMAL(13,2),
    units_in_stock INTEGER,
    units_on_order INTEGER,
    reorder_level INTEGER,
    discontinued integer NOT NULL,
    CONSTRAINT FOREIGN KEY (supplier_id)
        REFERENCES suppliers ( supplier_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FOREIGN KEY (category_id)
        REFERENCES categories ( category_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);


--
-- Name: region; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE region (
    region_id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    region_description VARCHAR(50) NOT NULL
);


--
-- Name: shippers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE shippers (
    shipper_id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    company_name VARCHAR(40) NOT NULL,
    phone VARCHAR(24)
);



--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE suppliers (
    supplier_id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    company_name VARCHAR(40) NOT NULL,
    contact_name VARCHAR(30),
    contact_title VARCHAR(30),
    address VARCHAR(60),
    city VARCHAR(15),
    region VARCHAR(15),
    postal_code VARCHAR(10),
    country VARCHAR(15),
    phone VARCHAR(24),
    fax VARCHAR(24),
    homepage TEXT
);


--
-- Name: territories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE territories (
    territory_id VARCHAR(20) NOT NULL PRIMARY KEY,
    territory_description VARCHAR(50) NOT NULL,
    region_id INTEGER NOT NULL,
    CONSTRAINT FOREIGN KEY (region_id)
        REFERENCES region ( region_id )
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);

