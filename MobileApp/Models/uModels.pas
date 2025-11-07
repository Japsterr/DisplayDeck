unit uModels;

interface

type
  TUser = record
    Id: Integer;
    OrganizationId: Integer;
    Email: string;
    Role: string;
  end;

  TDisplay = record
    Id: Integer;
    Name: string;
    Orientation: string;
  end;

  TCampaign = record
    Id: Integer;
    Name: string;
    Orientation: string;
  end;

implementation

end.
