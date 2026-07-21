page 50052 "FSN IntegrationMember"
{
    PageType = List;
    SourceTable = "FSN IntegrationMember";
    ApplicationArea = All;
    UsageCategory = Administration;


    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Card; Card)
                {
                }
                field("Club Code"; "Club Code")
                {
                    Visible = VisibleValue;
                }
                field("Scheme Code"; "Scheme Code")
                {
                    Visible = VisibleValue;
                }
                field("Customer No."; "Customer No.")
                {
                    Visible = VisibleValue;
                }
                field("Customer Name"; "Customer Name")
                {
                    Visible = VisibleValue;
                }
                field(Status; Status)
                {
                    Visible = VisibleValue;
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                    Visible = VisibleValue;
                }
                field("Store No."; "Store No.")
                {
                    Visible = VisibleValue;
                }
                field(Beneficiary; Beneficiary)
                {
                }
                field(Action; Action)
                {
                    Visible = VisibleValue;
                }
                field(StaffID; StaffID)
                {
                    Visible = VisibleValue;
                }
                field("Process Message"; "Process Message")
                {
                    Visible = VisibleValue;
                }
                field("Date Processed"; "Date Processed")
                {
                    Visible = VisibleValue;
                }
                field("Time Processed"; "Time Processed")
                {
                    Visible = VisibleValue;
                }
                field("User Process"; "User Process")
                {
                    Visible = VisibleValue;
                }
                field("Date Create Card"; "Date Create Card")
                {
                    Visible = VisibleValue;
                }
                field("Counter Process"; "Counter Process")
                {
                    Visible = VisibleValue;
                }
                field("Receipt No."; "Receipt No.")
                {
                    Visible = VisibleValue;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(Process)
            {
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = VisibleValue;

                trigger OnAction()
                var
                    ProcessMembers: Codeunit "FSN Integration Member";
                    lText001: Label 'All records processed successfull!';
                    IDSelected: Option " ","Only Selected",All;
                    LSMenu: Text[100];
                    lTextMenu: Label '&Card Selected %1, &All Pending';
                    lText002: Label 'Error. %1';
                    ErrorText: Text[100];
                    lText003: Label 'Card %1 processed successfull!';
                begin
                    LSMenu := STRSUBSTNO(lTextMenu, Card);
                    IDSelected := STRMENU(LSMenu, 1);


                    CASE IDSelected OF
                        0:
                            EXIT;
                        1:
                            BEGIN
                                IF ProcessMembers.ProcessMemberRecord(Rec, ErrorText) THEN BEGIN
                                    Rec.GET(Rec.Card);
                                    Rec.Status := Rec.Status::Processed;
                                    Rec."Process Message" := '';
                                    Rec."Date Processed" := TODAY;
                                    Rec."Time Processed" := TIME;
                                    Rec."User Process" := USERID;
                                    IF Rec.Action = Rec.Action::Create THEN
                                        Rec."Date Create Card" := TODAY;
                                    Rec."Counter Process" += 1;
                                    Rec.MODIFY;
                                END ELSE BEGIN
                                    Rec.GET(Rec.Card);
                                    Rec.Status := Rec.Status::Error;
                                    Rec."Process Message" := COPYSTR(ErrorText, 1, 100);
                                    Rec.MODIFY;
                                    MESSAGE(STRSUBSTNO(lText002, ErrorText));
                                    EXIT;
                                END;
                            END;
                        2:
                            BEGIN
                                ProcessMembers.ProcessALLRecords();
                            END;
                    END;
                    MESSAGE(lText001);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin

        IF possession.GetValue('#MEMBERPROCESS') = 'TRUE' THEN
            VisibleValue := false
        else
            VisibleValue := true;

        SETCURRENTKEY(Status);
        SETFILTER(Status, '<>%1', Status::Processed);
    end;

    var
        possession: Codeunit "LSC POS Session";
        VisibleValue: Boolean;
}

