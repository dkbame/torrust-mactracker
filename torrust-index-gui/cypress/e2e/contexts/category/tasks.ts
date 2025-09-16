// Custom tasks for category context

import { type DatabaseConfig, type DatabaseQuery, runDatabaseQuery } from "../../common/database";

// Task to delete a category
export const deleteCategory = async (name: string, db_config: DatabaseConfig): Promise<string> => {
  try {
    const result = await runDatabaseQuery(deleteCategoryQuery(name), db_config);
    return name;
  } catch (err) {
    return await Promise.reject(err);
  }
};

// Task to add a new category
export const addCategory = async (name: string, db_config: DatabaseConfig): Promise<string> => {
  try {
    const result = await runDatabaseQuery(addCategoryQuery(name), db_config);
    return name;
  } catch (err) {
    return await Promise.reject(err);
  }
};

// Database query specifications

function deleteCategoryQuery (name: string): DatabaseQuery {
  return {
    query: "DELETE FROM torrust_categories WHERE name = ?",
    params: [name]
  };
}

function addCategoryQuery (name: string): DatabaseQuery {
  return {
    query: "INSERT INTO torrust_categories (name) VALUES (?)",
    params: [name]
  };
}
