ALTER TABLE maintenance_requests ADD COLUMN company_id integer;
ALTER TABLE maintenance_requests ADD CONSTRAINT fk_company FOREIGN KEY (company_id) REFERENCES companies(id);