Table 50035 "FSN Scheduler Job Header"
{
    Caption = 'Scheduler Job Header';
    DataCaptionFields = "Job ID", Description;

    fields
    {
        field(10; "Job ID"; Code[20])
        {
            Caption = 'Job ID';
            NotBlank = true;
        }
        field(20; Description; Text[30])
        {
            Caption = 'Description';
        }
        field(30; "From-Location Code"; Code[10])
        {
            Caption = 'From-Location Code';
            TableRelation = "LSC Distribution Location".Code;

            trigger OnValidate()
            begin
                CalcFields("From-Location Description");

                if "From-Location Code" <> '' then
                    Validate("From Dist. Restrictions", "From Dist. Restrictions"::"Single Location");
            end;
        }
        field(40; "From-Location Description"; Text[100])
        {
            CalcFormula = Lookup("LSC Distribution Location".Description WHERE(Code = FIELD("From-Location Code")));
            Caption = 'From-Location Description';
            Editable = false;
            FieldClass = FlowField;
        }
        field(50; "Use Current Location"; Boolean)
        {
            Caption = 'Use Current Location';

            trigger OnValidate()
            begin
                if "Use Current Location" then begin
                    Validate("From-Location Code", '');
                    "From Dist. Restrictions" := "From Dist. Restrictions"::"Current Location";
                end;

                if ("From Dist. Restrictions" = "From Dist. Restrictions"::"Current Location") then
                    "Use Current Location" := true;
            end;
        }
        field(60; "Last Date Checked"; Date)
        {
            Caption = 'Last Date Checked';
            Editable = false;
            FieldClass = Normal;
        }
        field(70; "Last Time Checked"; Time)
        {
            Caption = 'Last Time Checked';
            Editable = false;
        }
        field(80; "Time Between Check"; Integer)
        {
            Caption = 'Time Between Check';
        }
        field(90; "Time Units"; Option)
        {
            Caption = 'Time Units';
            InitValue = Day;
            OptionCaption = 'Second,Minute,Hour,Day';
            OptionMembers = Second,Minute,Hour,Day;
        }
        field(100; "Next Check Date"; Date)
        {
            Caption = 'Next Check Date';
        }
        field(110; "Next Check Time"; Time)
        {
            Caption = 'Next Check Time';
        }
        field(120; "Run Status"; Option)
        {
            Caption = 'Run Status';
            Editable = false;
            OptionCaption = ' ,Processing,With Error,Stopped With Error,,Special Order';
            OptionMembers = " ",Processing,"With Error","Stopped With Error",,"Special Order";
        }
        field(130; "Error Handling"; Option)
        {
            Caption = 'Error Handling';
            OptionCaption = 'Skip To Next Run,Mark With Error and Retry,Mark With Error and Stop';
            OptionMembers = "Skip To Next Run","Mark With Error and Retry","Mark With Error and Stop";
        }
        field(140; "Error Occurred"; Boolean)
        {
            Caption = 'Error Occurred';
            Editable = false;
            FieldClass = Normal;
        }
        field(150; "Valid on Sundays"; Boolean)
        {
            Caption = 'Valid on Sundays';
            InitValue = true;
        }
        field(160; "Valid on Mondays"; Boolean)
        {
            Caption = 'Valid on Mondays';
            InitValue = true;
        }
        field(170; "Valid on Tuesdays"; Boolean)
        {
            Caption = 'Valid on Tuesdays';
            InitValue = true;
        }
        field(180; "Valid on Wednesdays"; Boolean)
        {
            Caption = 'Valid on Wednesdays';
            InitValue = true;
        }
        field(190; "Valid on Thursdays"; Boolean)
        {
            Caption = 'Valid on Thursdays';
            InitValue = true;
        }
        field(200; "Valid on Fridays"; Boolean)
        {
            Caption = 'Valid on Fridays';
            InitValue = true;
        }
        field(210; "Valid on Saturdays"; Boolean)
        {
            Caption = 'Valid on Saturdays';
            InitValue = true;
        }
        field(220; "Starting Time"; Time)
        {
            Caption = 'Starting Time';
        }
        field(230; "Ending Time"; Time)
        {
            Caption = 'Ending Time';
        }
        field(240; "Object Type"; Option)
        {
            Caption = 'Object Type';
            InitValue = "Codeunit";
            OptionCaption = ',,,Report,,Codeunit';
            OptionMembers = ,,,"Report",,"Codeunit";
        }
        field(250; "Object No."; Integer)
        {
            Caption = 'Object No.';
            TableRelation = AllObjWithCaption."Object ID" WHERE("Object Type" = FIELD("Object Type"));
            ValidateTableRelation = false;

            trigger OnValidate()
            begin
                Validate("Object Name");
                "Use Web Replication" := false;
            end;
        }
        field(260; "Object Name"; Text[30])
        {
            Caption = 'Object Name';
            Editable = false;

            trigger OnValidate()
            var
                AllObj: Record AllObj;
            begin
                if AllObj.Get("Object Type", "Object No.") then
                    "Object Name" := AllObj."Object Name"
                else
                    "Object Name" := '';
            end;
        }
        field(270; "Use Web Replication"; Boolean)
        {
            Caption = 'Use Web Replication';

            trigger OnValidate()
            var
                OnlyValidFor: Label 'Only Valid for codeunit 99008923 "Data Distribution WS"';
            begin
                IF not (("Object Type" = "Object Type"::Codeunit) and ("Object No." = Codeunit::"LSC Data Distribution WS")) then
                    error(OnlyValidFor);
            end;
        }
        field(280; "Uses Scheduler Job Record"; Boolean)
        {
            Caption = 'Uses Scheduler Job Record';
            InitValue = true;
        }
        field(290; "Last Message Text"; Text[250])
        {
            Caption = 'Last Message Text';
            Editable = false;
        }
        field(300; "Last Log Entry"; Integer)
        {
            Caption = 'Last Log Entry';
        }

        field(310; Text; Text[250])
        {
            Caption = 'Text';
            Description = 'Free variable';
        }
        field(320; "Code"; Code[50])
        {
            Caption = 'Code';
            Description = 'Free variable';
        }
        field(330; "Integer"; Integer)
        {
            Caption = 'Integer';
            Description = 'Free variable';
        }
        field(340; Decimal; Decimal)
        {
            Caption = 'Decimal';
            Description = 'Free variable';
        }
        field(350; Date; Date)
        {
            Caption = 'Date';
            Description = 'Free variable';
        }
        field(360; Time; Time)
        {
            Caption = 'Time';
            Description = 'Free variable';
        }
        field(370; Option; Option)
        {
            Caption = 'Option';
            Description = 'Free variable';
            OptionCaption = 'Doesn''t need translation';
            OptionMembers = "";
        }
        field(380; Boolean; Boolean)
        {
            Caption = 'Boolean';
            Description = 'Free variable';
        }
        field(390; DateFormula; DateFormula)
        {
            Caption = 'DateFormula';
            Description = 'Free variable';
        }
        field(400; "Calcdate Formula"; DateFormula)
        {
            Caption = 'Calcdate Formula';
        }
        field(410; "From Dist. Restrictions"; Option)
        {
            Caption = 'From Dist. Restrictions';
            OptionCaption = 'Current Location,Single Location,Include List';
            OptionMembers = "Current Location","Single Location","Include List";

            trigger OnValidate()
            var
                SchToLocList: Record "LSC Distrib. Incl./Excl. List";
                entries: Integer;
            begin
                if ("From Dist. Restrictions" = "From Dist. Restrictions"::"Current Location") then begin
                    "Use Current Location" := true;
                    Validate("From-Location Code", '');
                end;

                if ("From Dist. Restrictions" = "From Dist. Restrictions"::"Include List") then begin
                    "Use Current Location" := false;
                    Validate("From-Location Code", '');
                end;

                if ("From Dist. Restrictions" = "From Dist. Restrictions"::"Single Location") then begin
                    "Use Current Location" := false;
                end;

                SchToLocList.SetRange("Location List Type", SchToLocList."Location List Type"::From);
                SchToLocList.SetRange("Scheduler Job ID", Rec."Job ID");
                entries := SchToLocList.Count;
                if entries > 0 then begin
                    if ("From Dist. Restrictions" = "From Dist. Restrictions"::"Current Location") or
                       ("From Dist. Restrictions" = "From Dist. Restrictions"::"Include List") then
                        SchToLocList.DeleteAll(true)
                end;
            end;
        }
        field(420; "Use Job ID"; Code[20])
        {
            Caption = 'Use Job ID';
            TableRelation = "FSN Scheduler Job Header"."Job ID";
        }
        field(430; "Last Batch ID"; Code[20])
        {
            Caption = 'Last Batch ID';
        }
        field(440; "Retry Counter"; Integer)
        {
            Caption = 'Retry Counter';
        }
    }

    keys
    {
        key(Key1; "Job ID")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }


}
