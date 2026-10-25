package com.shubus.backend.controller;

import com.shubus.backend.dto.StudentProfileResponse;
import com.shubus.backend.dto.StudentResponse;
import com.shubus.backend.model.Student;
import com.shubus.backend.model.StudentTransportProfile;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.repository.StudentTransportProfileRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/students")
public class StudentController {

    private final StudentRepository studentRepository;
    private final StudentTransportProfileRepository profileRepository;

    public StudentController(
            StudentRepository studentRepository,
            StudentTransportProfileRepository profileRepository) {
        this.studentRepository = studentRepository;
        this.profileRepository = profileRepository;
    }

    /** Basic student details. */
    @GetMapping("/{regNo}")
    public StudentResponse getStudent(@PathVariable String regNo) {
        Student student = findStudent(regNo);
        return new StudentResponse(
                student.getRegNo(), student.getName(), student.getActive());
    }

    /**
     * One-call bootstrap endpoint for the SHUBUS module.
     * The host application supplies the registration number of its logged-in student;
     * SHUBUS does not ask the student to log in again.
     */
    @GetMapping("/{regNo}/profile")
    public StudentProfileResponse getStudentProfile(@PathVariable String regNo) {
        Student student = findStudent(regNo);

        if (!Boolean.TRUE.equals(student.getActive())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Student account is inactive");
        }

        StudentTransportProfile profile = profileRepository
                .findByStudentId(student.getId())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Transport profile not found"));

        return new StudentProfileResponse(
                student.getRegNo(),
                student.getName(),
                student.getActive(),
                profile.getMorningRouteNumber(),
                profile.getMorningRouteName(),
                profile.getAcType());
    }

    private Student findStudent(String regNo) {
        if (regNo == null || regNo.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Registration number is required");
        }
        return studentRepository.findByRegNo(regNo.trim())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Student not found"));
    }
}
