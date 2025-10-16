unit uServerContainer;

interface

uses
  System.Classes,
  FireDAC.Comp.Client;

type
  // Minimal cross-platform container to provide FDConnection for services
  TServerContainer = class
  public
    FDConnection: TFDConnection;
  end;

var
  ServerContainer: TServerContainer;

implementation

end.
