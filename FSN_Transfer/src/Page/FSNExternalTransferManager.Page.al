page 50109 "FSN External Transfer Manager"
{
    //JHERNANDEZ 1.0.0.14            - PROC TRANSFER FOR MULTISELECT
    Caption = 'FSN Administrar Transferencias Externas';
    ApplicationArea = Location;
    CardPageID = "Location Card";
    PageType = List;
    SourceTable = Location;
    UsageCategory = Administration;
    DeleteAllowed = false;
    InsertAllowed = false;
    layout
    {
        area(Content)
        {
            group(General)
            {
                field("Salas"; salas)
                {
                    ApplicationArea = Location;
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        recdref: RecordRef;
                        RecName: Page "Location List";
                        RecCodeunit: Codeunit SelectionFilterManagement;
                        recTabName: Record "Location";
                    begin
                        Clear(RecName);
                        Clear(recTabName);
                        recdref.GetTable(recTabName);
                        RecName.LookupMode := true;
                        if RecName.RunModal() = Action::LookupOK then begin
                            RecName.SetSelectionFilter(recTabName);
                            Text += RecCodeunit.GetSelectionFilterForLocation(recTabName);
                            exit(true);
                        end else
                            exit(false);
                    end;
                }
                field(FiltroFecha; FiltroFecha)
                {
                    ApplicationArea = ALL;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin

                    end;
                }

            }
        }

    }

    actions
    {
        area(navigation)
        {
            action("&Run Now")
            {
                ApplicationArea = All;
                Caption = '&Ejecutar Ahora';
                Image = Start;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    JobH.Init();
                    JobH.Code := salas;
                    if FiltroFecha <> '' then
                        JobH.Text := FiltroFecha;
                    if not Confirm(PROCESSJOB_CONFIRM, false, JobH."Job ID") then
                        exit;
                    ExTransferM.Run(JobH);
                end;
            }
        }
    }
    var
        salas, FiltroFecha : text;
        ExTransferM: Codeunit "FSN External Transfer Manager";
        JobH: Record "LSC Scheduler Job Header";

        PROCESSJOB_CONFIRM: Label '¿Desea procesar tarea  %1 ?';

}