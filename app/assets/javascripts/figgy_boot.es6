import SaveWorkControl from 'form/save_work_control'
import ServerUploader from "./server_uploader"
import StructureManager from "structure_manager"
import ModalViewer from "modal_viewer"
export default class Initializer {
  constructor() {
    this.server_uploader = new ServerUploader
    this.initialize_form()
    this.initialize_timepicker()
    this.structure_manager = new StructureManager
    this.modal_viewer = new ModalViewer
    $("select").selectpicker({'liveSearch': true})
  }

  initialize_timepicker() {
    $(".timepicker").datetimepicker({
      timeFormat: "HH:mm:ssZ",
      separator: "T",
      dateFormat: "yy-mm-dd",
      timezone: "0",
      showTimezone: false,
      showHour: false,
      showMinute: false,
      showSecond: false,
      hourMax: 0,
      minuteMax: 0,
      secondMax: 0
    })
  }

  initialize_form() {
    if($("#form-progress").length > 0) {
      new SaveWorkControl($("#form-progress"))
    }
  }
}
