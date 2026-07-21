page 50110 "FSN JOB FASANI"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Scheduler Job Header";
    Editable = true;

    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                Caption = 'General';
                field("Job ID"; Rec."Job ID")
                {
                    ApplicationArea = All;
                }
            }
            group("Object Setup")
            {
                Caption = 'Configuración Objetos';
                field("Object Type"; Rec."Object Type")
                {
                    Caption = 'Tipo Objeto';
                    ApplicationArea = All;
                }
                field("Object No."; Rec."Object No.")
                {
                    Caption = 'No. Objeto';
                    ApplicationArea = All;
                }
                field("Object Name"; Rec."Object Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Use Web Replication"; Rec."Use Web Replication")
                {
                    ApplicationArea = All;
                }
                field("Uses Scheduler Job Record"; Rec."Uses Scheduler Job Record")
                {
                    ApplicationArea = All;
                }
                field("Use Job ID"; Rec."Use Job ID")
                {
                    ApplicationArea = All;
                }
                field("Last Batch ID"; Rec."Last Batch ID")
                {
                    ApplicationArea = All;
                }
                field(Text; Rec.Text)
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        ModifyParameter();
                    end;
                }
                field("Code"; Rec.Code)
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        ModifyParameter();
                    end;
                }
                field("Integer"; Rec.Integer)
                {
                    ApplicationArea = All;
                }
                field(Decimal; Rec.Decimal)
                {
                    ApplicationArea = All;
                }
                field(Date; Rec.Date)
                {
                    ApplicationArea = All;
                }
                field(Time; Rec.Time)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field(Boolean; Rec.Boolean)
                {
                    ApplicationArea = All;
                }
                field(DateFormula; Rec.DateFormula)
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        ModifyParameter();
                    end;
                }
            }
            group("Schedule Details")
            {
                Caption = 'Schedule Details';
                field("Time Units"; Rec."Time Units")
                {
                    ApplicationArea = All;
                }
                field("Time Between Check"; Rec."Time Between Check")
                {
                    ApplicationArea = All;
                }
                field("Next Check Date"; Rec."Next Check Date")
                {
                    ApplicationArea = All;
                }
                field("Next Check Time"; Rec."Next Check Time")
                {
                    ApplicationArea = All;
                }
                field("Starting Time"; Rec."Starting Time")
                {
                    ApplicationArea = All;
                }
                field("Ending Time"; Rec."Ending Time")
                {
                    ApplicationArea = All;
                }
                field("Valid on Sundays"; Rec."Valid on Sundays")
                {
                    ApplicationArea = All;
                }
                field("Valid on Mondays"; Rec."Valid on Mondays")
                {
                    ApplicationArea = All;
                }
                field("Valid on Tuesdays"; Rec."Valid on Tuesdays")
                {
                    ApplicationArea = All;
                }
                field("Valid on Wednesdays"; Rec."Valid on Wednesdays")
                {
                    ApplicationArea = All;
                }
                field("Valid on Thursdays"; Rec."Valid on Thursdays")
                {
                    ApplicationArea = All;
                }
                field("Valid on Fridays"; Rec."Valid on Fridays")
                {
                    ApplicationArea = All;
                }
                field("Valid on Saturdays"; Rec."Valid on Saturdays")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                Caption = 'Cambiar Estatus';
                Image = ChangeStatus;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    Rec."Run Status" := Rec."Run Status"::" ";
                    Rec.Modify();
                    CurrPage.Update(false);
                end;
            }

            action(RunProcess)
            {
                Caption = 'Ejecutar Ahora';
                ApplicationArea = All;
                Image = Start;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    Job: Record "LSC Scheduler Job Header";
                begin
                    //ModifyParameter();
                    if Rec."Uses Scheduler Job Record" then begin
                        Job.Init();
                        Job.Text := Rec.Text;
                        Job.Code := Rec.Code;
                        Job.Integer := Rec.Integer;
                        Job.Decimal := Rec.Decimal;
                        Job.Date := Rec.Date;
                        Job.Time := Rec.Time;
                        Job.Boolean := Rec.Boolean;
                        Job.DateFormula := Rec.DateFormula;
                        if Codeunit.Run(Rec."Object No.", Job) then;
                    end else
                        if Codeunit.Run(Rec."Object No.") then;
                end;
            }

            action(StopWebServiceExecutions)
            {
                Caption = 'Detener Ejecución de Web Services';
                ApplicationArea = All;
                Image = Stop;
                trigger OnAction()
                begin
                    StopWebServiceExecution();
                end;
            }
        }
    }

    var
        Parameter: Record "FSN Parameter";

    procedure ModifyParameter()
    var
        myInt: Integer;
    begin

        Parameter.Reset();
        Parameter.SetRange(Grupo, 'CONF');
        Parameter.SetRange(Codigo, 'STATEMENT');
        Parameter.SetRange(Activo, true);
        if Parameter.FindSet() then begin
            Parameter.Descripcion := Rec.Text;
            Parameter."Value Text 1" := Format(Rec.DateFormula);
            Parameter.Valor := Rec.Code;
            Parameter."Lookup ID 1" := '';
            Parameter."Lookup ID 2" := '';
            Parameter.Modify(true);
        end;
    end;

    local procedure StopWebServiceExecution()
    var
        ActiveSession: Record "Active Session";
    begin
        ActiveSession.Reset();
        ActiveSession.SetRange("User ID", 'FASANI\WS');
        If ActiveSession.FindFirst() then
            ActiveSession.Delete();
    end;

    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        ModifyParameter();
    end;
}