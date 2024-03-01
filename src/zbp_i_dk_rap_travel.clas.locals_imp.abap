CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF travel_status,
        open     TYPE c LENGTH 1 VALUE 'O', " Open
        accepted TYPE c LENGTH 1 VALUE 'A', " Accepted
        canceled TYPE c LENGTH 1 VALUE 'X', " Cancelled
      END OF travel_status.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Travel RESULT result.

    METHODS is_update_granted IMPORTING has_before_image      TYPE abap_bool
                                        overall_status        TYPE /dmo/overall_status
                              RETURNING VALUE(update_granted) TYPE abap_bool.
    METHODS is_delete_granted IMPORTING has_before_image      TYPE abap_bool
                                        overall_status        TYPE /dmo/overall_status
                              RETURNING VALUE(delete_granted) TYPE abap_bool.
    METHODS is_create_granted RETURNING VALUE(create_granted) TYPE abap_bool.

    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.

    METHODS reCalculateTotalPrice FOR MODIFY
      IMPORTING keys FOR ACTION Travel~reCalculateTotalPrice.

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~calculateTotalPrice.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~setInitialStatus.

    METHODS calculateTravelID FOR DETERMINE ON SAVE
      IMPORTING keys FOR Travel~calculateTravelID.

    METHODS validateAgency FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateAgency.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateCustomer.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateDates.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Travel RESULT result.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_instance_features.
    " Read the travel status of the existing travels

    READ ENTITIES OF ZI_DK_rAP_TRAVEL IN LOCAL MODE
    ENTITY Travel
    FIELDS ( OverallStatus ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels) FAILED failed.

*    result = VALUE #( FOR travel IN travels
*                            LET IS_aCCEPTED = COND #( WHEN travel-OverallStatus = travel_status-accepted
*                                THEN if_abap_behv=>fc-o-enabled
*                                ELSE if_abap_behv=>fc-o-disabled )
*
*                                is_rejected = COND #( WHEN travel-OverallStatus = travel_status-canceled
*                                THEN if_abap_behv=>fc-o-enabled
*                                ELSE if_abap_behv=>fc-o-disabled )
*                              IN ( %tky = travel-%tky %action-acceptTravel = is_accepted %action-rejectTravel = is_rejected )
*                                ).

    " the above logic is not correct.. this is to enable the button accept/reject travel.. and the logic says..
    "if Status = A then enable accept.. but its already accepted and if status = X, then enable reject but its already rejected.
*ideally the logic shud be if its not A or X then both should be enabled.or if is rejected then enable for accepted or if accepted enable it for rejection.
    result = VALUE #( FOR travel IN travels
                            LET IS_aCCEPTED = COND #( WHEN travel-OverallStatus = travel_status-canceled OR travel-OverallStatus = travel_status-open
                                THEN if_abap_behv=>fc-o-enabled
                                ELSE if_abap_behv=>fc-o-disabled )

                                is_rejected = COND #( WHEN travel-OverallStatus = travel_status-accepted OR travel-OverallStatus = travel_status-open
                                THEN if_abap_behv=>fc-o-enabled
                                ELSE if_abap_behv=>fc-o-disabled )
                              IN ( %tky = travel-%tky %action-acceptTravel = is_accepted %action-rejectTravel = is_rejected )
                                ).
  ENDMETHOD.
*
  METHOD get_instance_authorizations.
    DATA: has_before_image    TYPE abap_bool,
          is_update_requested TYPE abap_bool,
          is_delete_requested TYPE abap_bool,
          update_granted      TYPE abap_bool,
          delete_granted      TYPE abap_bool.

    DATA: failed_travel LIKE LINE OF failed-travel.
    " read the existing travel instance
    READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE ENTITY Travel
    FIELDS ( OverallStatus ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels) FAILED failed.

    CHECK travels IS NOT INITIAL.
    " here the authorization is defined based on the activity + overall travel status

    " for the travel status we need the before image from the database. we perform this for active( is_draft =00) as well
    "for draft(is_draft = 01) as we cannot distinguish between edit or new drafts

    SELECT FROM zdk_rap_atrav FIELDS travel_uuid, overall_status FOR ALL ENTRIES IN @travels
    WHERE travel_uuid = @travels-TravelUuid ORDER BY PRIMARY KEY
    INTO TABLE @DATA(travels_before_image).

    is_update_requested = COND #( WHEN requested_authorizations-%update = if_abap_behv=>mk-on OR
                                       requested_authorizations-%action-acceptTravel = if_abap_behv=>mk-on OR
                                       requested_authorizations-%action-rejectTravel = if_abap_behv=>mk-on OR
                                       requested_authorizations-%action-Prepare = if_abap_behv=>mk-on OR
                                       requested_authorizations-%action-Edit = if_abap_behv=>mk-on OR
                                       requested_authorizations-%assoc-_Booking = if_abap_behv=>mk-on
                                       THEN abap_True ELSE abap_false
                                       ).
    is_delete_requested = COND #( WHEN requested_authorizations-%delete = if_abap_behv=>mk-on THEN abap_true ELSE abap_false ).

    LOOP AT travels INTO DATA(travel).
      update_granted = delete_granted = abap_false.

      READ TABLE travels_before_image INTO DATA(travel_before_image) WITH KEY travel_uuid = travel-TravelUuid BINARY SEARCH.
      has_before_image = COND #( WHEN sy-subrc = 0 THEN abap_True ELSE abap_false ).
      IF is_update_requested = abap_True. " edit of an existing record
        IF has_before_image = abap_True.
          update_granted = is_update_granted(
            has_before_image = has_before_image
            overall_status   = travel-OverallStatus
          ).
          IF update_Granted = abap_False.
            APPEND VALUE #( %tky = travel-%tky %msg = NEW zcx_dk_rap(
                            severity = if_abap_behv_message=>severity-error
                            textid   = zcx_dk_rap=>unauthorized
                            ) ) TO reported-travel.
          ENDIF.
        ELSE. " creation of new record
          update_Granted = is_create_granted( ).
          IF update_granted = abap_false.
            APPEND VALUE #( %tky = travel-%tky %msg = NEW zcx_dk_rap(
                            severity = if_abap_behv_message=>severity-error
                            textid   = zcx_dk_rap=>unauthorized
                            ) ) TO reported-travel.
          ENDIF.
        ENDIF.
      ENDIF.

      IF is_delete_requested = abap_true.
        delete_granted = is_delete_granted(
          has_before_image = has_before_image
          overall_status   = travel-OverallStatus
        ).
        IF delete_granted = abap_false.
          APPEND VALUE #( %tky = travel-%tky %msg = NEW zcx_dk_rap(
                          severity = if_abap_behv_message=>severity-error
                          textid   = zcx_dk_rap=>unauthorized
                          ) ) TO reported-travel.
        ENDIF.
      ENDIF.

      APPEND VALUE #( %tky = travel-%tky
                      %update   = COND #( WHEN update_granted = abap_True THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
                      %delete   = COND #( WHEN delete_granted = abap_True THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
                      %action-acceptTravel   = COND #( WHEN update_granted = abap_True THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
                      %action-rejectTravel   = COND #( WHEN update_granted = abap_True THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
                      %action-Prepare   = COND #( WHEN update_granted = abap_True THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
                      %action-Edit   = COND #( WHEN update_granted = abap_True THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
                      %assoc-_booking    = COND #( WHEN update_granted = abap_True THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
      ) TO result.


    ENDLOOP.


  ENDMETHOD.

  METHOD acceptTravel.
    " perform modification
    MODIFY ENTITIES OF zi_dk_rap_travel IN LOCAL MODE
    ENTITY Travel
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR key IN keys
                  ( %key          = key-%key
                    OverallStatus = travel_status-accepted " accepted
                  )
    )
    FAILED DATA(lt_failed)
    REPORTED DATA(lt_reported).

    " fill response table
    READ ENTITIES OF zi_dk_rap_travel
    IN LOCAL MODE
    ENTITY Travel
     ALL FIELDS WITH CORRESPONDING #( keys )
     RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result
                      ( %tky   = ls_result-%tky "txn key
                        %param = ls_result " full result set of travel
                      )
    ).

  ENDMETHOD.

  METHOD reCalculateTotalPrice.
    TYPES: BEGIN OF ty_amount_per_currencycode,
             amount        TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_amount_per_currencycode.

    DATA: amount_per_currencycode TYPE STANDARD TABLE OF ty_amount_per_currencycode.
    " Read all relevant travel instances.
    READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE
    ENTITY Travel
    ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(travels).

    DELETE travels WHERE CurrencyCode IS INITIAL.

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
      " Set the start for the calculation by adding the booking fee.
      amount_per_currencycode = VALUE #( ( amount = <travel>-BookingFee currency_code = <travel>-CurrencyCode ) ).
      " Read all associated bookings and add them to the total price.

      READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE ENTITY Travel BY \_Booking
          FIELDS ( FlightPrice CurrencyCode ) WITH VALUE #( ( %key = <travel>-%key ) )
          RESULT DATA(bookings).

      LOOP  AT bookings INTO DATA(booking) WHERE CurrencyCode IS NOT INITIAL.
        COLLECT VALUE ty_amount_per_currencycode(  amount = booking-FlightPrice currency_code = booking-CurrencyCode ) INTO amount_per_currencycode.
      ENDLOOP.

      CLEAR <travel>-TotalPrice.
      LOOP AT amount_per_currencycode INTO DATA(single_amount_per_currencycode).
        " PERFORM CURRENCY CONVERSION
        IF single_amount_per_currencycode-currency_code = <travel>-CurrencyCode.
          <travel>-TotalPrice += single_amount_per_currencycode-amount.
        ELSE.
          /dmo/cl_flight_amdp=>convert_currency(
            EXPORTING
              iv_amount               = single_amount_per_currencycode-amount
              iv_currency_code_source = single_amount_per_currencycode-currency_code
              iv_currency_code_target = <travel>-CurrencyCode
              iv_exchange_rate_date   = cl_abap_context_info=>get_system_date( )
            IMPORTING
              ev_amount               = DATA(total_booking_price_per_curr)
          ).
          <travel>-TotalPrice += total_booking_price_per_curr.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    " write back the modified total_price of travels
    MODIFY ENTITIES OF zi_dk_rap_travel IN LOCAL MODE ENTITY Travel
    UPDATE FIELDS ( TotalPrice ) WITH CORRESPONDING #( travels )
    REPORTED DATA(lt_reported)
    FAILED DATA(lt_failed).


  ENDMETHOD.

  METHOD rejectTravel.
    " perform modification
    MODIFY ENTITIES OF zi_dk_rap_travel IN LOCAL MODE
    ENTITY Travel
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR key IN keys
                  ( %key          = key-%key
                    OverallStatus = travel_status-canceled " cancelled
                  )
    )
    FAILED DATA(lt_failed)
    REPORTED DATA(lt_reported).

    " fill response table
    READ ENTITIES OF zi_dk_rap_travel
    IN LOCAL MODE
    ENTITY Travel
     ALL FIELDS WITH CORRESPONDING #( keys )
     RESULT DATA(lt_result).

    result = VALUE #( FOR ls_result IN lt_result
                      ( %tky   = ls_result-%tky "txn key
                        %param = ls_result " full result set of travel
                      )
    ).

  ENDMETHOD.

  METHOD calculateTotalPrice.
    MODIFY ENTITIES OF zi_dk_rap_travel IN LOCAL MODE
    ENTITY travel
    EXECUTE reCalculateTotalPrice
    FROM CORRESPONDING #( keys )
    REPORTED DATA(execute_reported).

    reported = CORRESPONDING #( DEEP execute_reported ).
  ENDMETHOD.

  METHOD setInitialStatus.
    " Read relevant travel instance data

    READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE

    ENTITY Travel

    FIELDS ( OverallStatus ) WITH CORRESPONDING #( keys )

    RESULT DATA(travels).
    " Remove all travel instance data with defined status

    DELETE travels WHERE OverallStatus IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.
    " Set default travel status

    MODIFY ENTITIES OF zi_dk_rap_travel IN LOCAL MODE

    ENTITY Travel

    UPDATE

    FIELDS ( OverallStatus )

    WITH VALUE #( FOR travel IN travels

                  ( %tky          = travel-%tky

                    OverallStatus = travel_status-open ) )

    REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

  ENDMETHOD.

  METHOD calculateTravelID.
    " Please note that this is just an example for calculating a field during _onSave_.
    " This approach does NOT ensure for gap free or unique travel IDs! It just helps to provide a readable ID.
    " The key of this business object is a UUID, calculated by the framework.
    " check if TravelID is already filled

    READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE
    ENTITY Travel
    FIELDS ( TravelID ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels).
    " remove lines where TravelID is already filled.

    DELETE travels WHERE TravelID IS NOT INITIAL.
    " anything left ?

    CHECK travels IS NOT INITIAL.

    " Select max travel ID

    SELECT SINGLE
    FROM ZDK_RAP_aTRAV
    FIELDS MAX( travel_id ) AS travelID
    INTO @DATA(max_travelid).

    " Set the travel ID

    MODIFY ENTITIES OF zi_dk_rap_travel IN LOCAL MODE
    ENTITY Travel
    UPDATE
    FROM VALUE #( FOR travel IN travels INDEX INTO i (

                  %tky              = travel-%tky
                  TravelID          = max_travelid + 1
                  %control-TravelID = if_abap_behv=>mk-on ) )
    REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).

  ENDMETHOD.

  METHOD validateAgency.
    " read travel instance
    READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE
    ENTITY Travel
        FIELDS ( AgencyId ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_result).

    DATA agencies TYPE SORTED TABLE OF /dmo/agency WITH UNIQUE KEY agency_id.
    agencies = CORRESPONDING #( lt_Result DISCARDING DUPLICATES MAPPING agency_id = AgencyId EXCEPT * ).

    DELETE agencies WHERE agency_id IS INITIAL.
    IF agencies IS  NOT INITIAL.
      " check if it exist
      SELECT FROM /dmo/agency FIELDS agency_id
      FOR ALL ENTRIES IN @agencies
      WHERE agency_id = @agencies-agency_id INTO TABLE @DATA(lt_agency_db).
    ENDIF.
    " Raise msg for non existing and initial agencyID
    LOOP AT lt_Result INTO DATA(ls_result).
      "clear any state that exist
      APPEND VALUE #( %tky = ls_result-%tky %state_area = 'VALIDATE_AGENCY' ) TO reported-travel.

      IF ls_Result-AgencyId IS INITIAL OR NOT line_Exists( lt_agency_db[ agency_id = ls_Result-AgencyId ] ).
        APPEND VALUE #( %tky = ls_result-%tky ) TO failed-travel.

        APPEND VALUE #( %tky              = ls_result-%tky %state_area = 'VALIDATE_AGENCY' %msg =
                        NEW zcx_dk_rap(
                        severity = if_abap_behv_message=>severity-error
                        textid   = zcx_dk_rap=>agency_unknown
*          previous   =
*          begindate  =
*          enddate    =
*          travelid   =
*          customerid =
                        agencyid = ls_result-AgencyId
                        )
                        %element-AgencyId = if_abap_behv=>mk-on
        )
        TO reported-travel.


      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD validateCustomer.
    " Read relevant travel instance data

    READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE

    ENTITY Travel

    FIELDS ( CustomerID ) WITH CORRESPONDING #( keys )

    RESULT DATA(travels).

    DATA customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    " Optimization of DB select: extract distinct non-initial customer IDs

    customers = CORRESPONDING #( travels DISCARDING DUPLICATES MAPPING customer_id = CustomerID EXCEPT * ).

    DELETE customers WHERE customer_id IS INITIAL.

    IF customers IS NOT INITIAL.

      " Check if customer ID exist

      SELECT FROM /dmo/customer FIELDS customer_id

      FOR ALL ENTRIES IN @customers

      WHERE customer_id = @customers-customer_id

      INTO TABLE @DATA(customers_db).

    ENDIF.

    " Raise msg for non existing and initial customerID

    LOOP AT travels INTO DATA(travel).

      " Clear state messages that might exist

      APPEND VALUE #( %tky        = travel-%tky

                      %state_area = 'VALIDATE_CUSTOMER' )

      TO reported-travel.

      IF travel-CustomerID IS INITIAL OR NOT line_exists( customers_db[ customer_id = travel-CustomerID ] ).

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky                = travel-%tky

                        %state_area         = 'VALIDATE_CUSTOMER'

                        %msg                = NEW zcx_dk_rap(

                        severity   = if_abap_behv_message=>severity-error

                        textid     = zcx_dk_rap=>customer_unknown

                        customerid = travel-CustomerID )

                        %element-CustomerID = if_abap_behv=>mk-on )

        TO reported-travel.

      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    " Read relevant travel instance data

    READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE

    ENTITY Travel

    FIELDS ( TravelID BeginDate EndDate ) WITH CORRESPONDING #( keys )

    RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).

      " Clear state messages that might exist

      APPEND VALUE #( %tky        = travel-%tky

                      %state_area = 'VALIDATE_DATES' )

      TO reported-travel.

      IF travel-EndDate < travel-BeginDate.

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky

                        %state_area        = 'VALIDATE_DATES'

                        %msg               = NEW zcx_dk_rap(

                        severity  = if_abap_behv_message=>severity-error

                        textid    = zcx_dk_rap=>date_interval

                        begindate = travel-BeginDate

                        enddate   = travel-EndDate

                        travelid  = travel-TravelID )

                        %element-BeginDate = if_abap_behv=>mk-on

                        %element-EndDate   = if_abap_behv=>mk-on ) TO reported-travel.

      ELSEIF travel-BeginDate < cl_abap_context_info=>get_system_date( ).

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky

                        %state_area        = 'VALIDATE_DATES'

                        %msg               = NEW zcx_dk_rap(

                        severity  = if_abap_behv_message=>severity-error

                        textid    = zcx_dk_rap=>begin_date_before_system_date

                        begindate = travel-BeginDate )

                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.

      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD is_create_granted.
    AUTHORITY-CHECK OBJECT 'ZDKOSTAT'
    ID 'ZDKOSTAT' DUMMY
    ID 'ACTVT' FIELD '01'.

    create_granted  = COND #( WHEN sy-subrc = 0 THEN abap_True ELSE abap_false ).
    "simulate full access

    create_Granted = abap_true.
  ENDMETHOD.

  METHOD is_delete_granted.
    IF has_before_image = abap_true.
      AUTHORITY-CHECK OBJECT 'ZDKOSTAT'
      ID 'ZDKOSTAT' FIELD overall_status
      ID 'ACTVT' FIELD '06'.
    ELSE.
      AUTHORITY-CHECK OBJECT 'ZDKOSTAT'
      ID 'ZDKOSTAT' DUMMY
      ID 'ACTVT' FIELD '06'.
    ENDIF.
    delete_granted = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
    " Simulate full access - for testing purposes only! Needs to be removed for a productive implementation.
    delete_granted = abap_true.
  ENDMETHOD.

  METHOD is_update_granted.
    IF has_before_image = abap_true.
      AUTHORITY-CHECK OBJECT 'ZDKOSTAT'
      ID 'ZDKOSTAT' FIELD overall_status
      ID 'ACTVT' FIELD '02'.
    ELSE.
      AUTHORITY-CHECK OBJECT 'ZDKOSTAT'
      ID 'ZDKOSTAT' DUMMY
      ID 'ACTVT' FIELD '02'.
    ENDIF.
    update_granted = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
    " Simulate full access - for testing purposes only! Needs to be removed for a productive implementation.
    update_granted = abap_true.
  ENDMETHOD.

*  METHOD get_instance_authorizations.
*  ENDMETHOD.

ENDCLASS.
