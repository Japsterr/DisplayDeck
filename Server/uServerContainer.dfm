object ServerContainer: TServerContainer
  OnCreate = DataModuleCreate
  Height = 210
  Width = 431
  object SparkleHttpSysDispatcher: TSparkleHttpSysDispatcher
    Active = False
    Left = 72
    Top = 16
  end
  object XDataServer: TXDataServer
    BaseUrl = 'http://+:2001/tms/xdata'
    Dispatcher = SparkleHttpSysDispatcher
    Pool = XDataConnectionPool
    SwaggerOptions.Enabled = True
    SwaggerUIOptions.Enabled = True
    EntitySetPermissions = <>
    Left = 216
    Top = 16
  end
  object FDConnection: TFDConnection
    Params.Strings = (
      'DriverID=PG')
    LoginPrompt = False
    Left = 72
    Top = 72
  end
  object XDataConnectionPool: TXDataConnectionPool
    Connection = FDConnection
    Left = 216
    Top = 72
  end
end
