# Aurelius Documentation Summary

This document summarizes the key findings from the TMS Aurelius user guide, specifically regarding database connectivity.

## Database Connectivity

To connect to a database, Aurelius uses an `IDBConnection` interface. This can be obtained in two ways:

1.  **Adapter Mode**: Using a 3rd party component like FireDAC (`TFDConnection`).
2.  **Native Driver Mode**: Connecting directly to the database.

We are using **Adapter Mode** with FireDAC.

### Key Steps for FireDAC Adapter Mode

1.  **Register SQL Dialect**: The PostgreSQL SQL dialect must be registered for Aurelius to use. This is done by adding the `Aurelius.Sql.PostgreSQL` unit to the project's `uses` clause.

2.  **Register Schema Importer**: To allow Aurelius to manage the database schema (create/update tables), the schema importer for PostgreSQL must also be registered. This is done by adding `Aurelius.Schema.PostgreSQL` to the `uses` clause.

3.  **Create `IDBConnection`**: An `IDBConnection` interface is created by passing a configured `TFDConnection` component to a `TFireDacConnectionAdapter`.

    ```delphi
    uses
      {...}, Aurelius.Drivers.Interfaces, Aurelius.Drivers.FireDac;

    var
      MyConnection: IDBConnection;
      FDConnection1: TFDConnection;
    begin
      // 1. Create and configure the TFDConnection component
      FDConnection1 := TFDConnection.Create(nil);
      FDConnection1.DriverName := 'PG'; // CRITICAL: This sets the FireDAC driver for PostgreSQL
      FDConnection1.Params.Values['Database'] := 'displaydeck';
      FDConnection1.Params.Values['UserName'] := 'postgres';
      FDConnection1.Params.Values['Password'] := 'admin';
      FDConnection1.Params.Values['Server'] := 'localhost';
      FDConnection1.Params.Values['Port'] := '5432';
      FDConnection1.LoginPrompt := False;

      // 2. Create the adapter
      // The second parameter (True) means the FDConnection1 component will be destroyed
      // when the MyConnection interface is released.
      MyConnection := TFireDacConnectionAdapter.Create(FDConnection1, True);

      // 3. Use the connection
      Manager := TObjectManager.Create(MyConnection);
      {...}
    end;
    ```

### Analysis of Previous Failures

The recurring error `[FireDAC][Comp][Clnt]-340. Driver ID is not defined` was likely caused by one of two issues:

1.  **Missing SQL Dialect Registration**: The `Aurelius.Sql.PostgreSQL` unit was not included in the project, so Aurelius did not know how to generate SQL for PostgreSQL.
2.  **Incorrect `TFDConnection` Configuration**: The `DriverName` property of the `TFDConnection` component was not being set to `'PG'`. While I was setting other parameters, this specific property is what tells FireDAC which driver to load, and its absence is the direct cause of the error message.

The proposed solution will address both of these issues.
