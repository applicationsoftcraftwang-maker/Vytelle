from sqlalchemy import text
import math
import datetime 
from ..classes import Security
from evernode.models import DatabaseModel

class Paginate:
    """ Make pagination easy """

    __filters = []
    model = None
    limit = None
    table_name = None
    is_view = None

    def __init__(self, limit, is_view = False, table_name = None):
        self.__filters = []
        self.is_view = is_view
        self.table_name = table_name
        self.limit = limit
    
    def __filter_query(self) -> str:
        """ Generate a WHERE/AND string for SQL"""
        filter_query = 'WHERE %s'
        bind_values = {}
        if not self.__filters:
            return None
        for filter in self.__filters:
            bind = {
                'name': Security.random_string(5),
                'value': filter['value']}
            if isinstance(filter['value'], str):
                #filter_str = 'lower(%s) %s :%s' % \
                filter_str = '%s %s :%s' % \
                    (filter['column'], filter['operator'], bind['name'])
                bind_values[bind['name']] = bind['value']
            elif isinstance(filter['value'], datetime.date):
                filter_str = '%s %s :%s' % \
                    (filter['column'], filter['operator'], bind['name'])
                bind_values[bind['name']] = bind['value'].strftime("%Y-%m-%d %H:%M:%S")                
            else:
                filter_str = '%s %s :%s' % \
                    (filter['column'], filter['operator'], bind['name'])
                bind_values[bind['name']] = bind['value']
            
            if filter['logical'] == 'AND':
                filter_query = filter_query % (filter_str + ' AND %s')
            elif filter['logical'] == 'OR':
                filter_query = filter_query % (filter_str + ' OR %s')
        return {
            'query': filter_query.replace(' AND %s', ''),
            'binds': bind_values}

    def add_filter(self, column, operator, value, logicaloperator='AND'):
        self.__filters.append({
            'column': column,
            'operator': operator,
            'value': value,
            'logical':logicaloperator
        })
        return self

    def total_count(self):
        total_sql = 'SELECT * FROM %s {} %s' \
            % (self.table_name)

    def page(self, order_by, engine, page_no=1):
        """ Return [models] by page_number based on limit """
        # workaround flask-sqlalchemy/issues/516
        offset = (page_no - 1) * self.limit
        
        sql = None
        if order_by == "not_apply":
            sql = 'SELECT * FROM %s {} LIMIT :li OFFSET :o ' \
            % (self.table_name)
        else:    
            sql = 'SELECT * FROM %s {} %s LIMIT :li OFFSET :o ' \
                % (self.table_name, order_by)

        filter_query = self.__filter_query()
        result = None
        total_result = None
        if filter_query is None:
            filter_query = {
                'query': '',
                'binds': {}
            }
            filter_query['binds']['li'] = self.limit
            filter_query['binds']['o'] = offset

            total_sql = sql[: sql.find('ORDER')].strip()
            total_sql = text(total_sql.format(''))
            sql = text(sql.format(''))            
            
            if self.is_view:
                total_result = engine.execute(total_sql, **filter_query['binds'])
                result = engine.execute(sql, **filter_query['binds'])
            else:
                total_result = engine.execute(total_sql,  **filter_query['binds'])            
                result = engine.execute(sql, **filter_query['binds'])

            filter_query = None
        else:
            filter_query['binds']['li'] = self.limit
            filter_query['binds']['o'] = offset
            total_sql = None
            if order_by == "not_apply":
                total_sql = sql[: sql.find('LIMIT')].strip()
            else:
                total_sql = sql[: sql.find('ORDER')].strip()

            sql = sql.format(filter_query['query'])
            total_sql = total_sql.format(filter_query['query'])
            total_sql = text(total_sql)
            sql = text(sql)

            if self.is_view:
                total_result = engine.execute(total_sql, **filter_query['binds'])
                result = engine.execute(sql, **filter_query['binds'])
            else:
                total_result = engine.execute(total_sql, **filter_query['binds'])
                result = engine.execute(sql, **filter_query['binds'])
        
        total_ids = []
        for row in total_result:
            total_ids.append(row[0])
        total_count = len(total_ids)

        return total_count, result
 
    def json_paginate(self, base_url, page_no, engine, column_name, order_by="not_apply"):
        """ Return a dict for a JSON paginate """
        total_count, result = self.page(order_by, engine, page_no)
        
        first_id = 0
        last_id = 0
        rows = None
        if result:
            result_keys = result.keys()
            if result_keys:
                index_column_name = result.keys().index(column_name)
                rows = result.fetchall()
                if bool(rows):
                    first_id = rows[0][index_column_name]
                    last_id = rows[-1][index_column_name]
            
        return rows, total_count, first_id, last_id
 