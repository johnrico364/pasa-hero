import * as yup from "yup";
import { BUS_STATUS_OPTIONS } from "../mapApiBus";

export const editBusSchema = yup.object({
  bus_code: yup.string().required("Bus code is required").trim(),
  plate_number: yup.string().required("Plate number is required").trim(),
  maximum_capacity: yup
    .number()
    .typeError("Must be a number")
    .required("Maximum capacity is required")
    .integer("Must be a whole number")
    .min(1, "Must be at least 1")
    .max(999, "Must be 999 or less"),
  status: yup
    .string()
    .oneOf([...BUS_STATUS_OPTIONS], "Invalid status")
    .required("Status is required"),
});

export type EditBusFormData = yup.InferType<typeof editBusSchema>;
