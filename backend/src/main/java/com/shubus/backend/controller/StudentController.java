package com.shubus.backend.controller;

import com.shubus.backend.dto.StudentResponse;
import com.shubus.backend.model.Student;
import com.shubus.backend.repository.StudentRepository;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/students")
public class StudentController {

    private final StudentRepository studentRepository;

    public StudentController(StudentRepository studentRepository) {
        this.studentRepository = studentRepository;
    }

    @GetMapping("/{regNo}")
    public StudentResponse getStudent(@PathVariable String regNo) {

        Student student = studentRepository.findByRegNo(regNo)
                .orElseThrow(() -> new RuntimeException("Student not found"));

        return new StudentResponse(
                student.getRegNo(),
                student.getName(),
                student.getActive()
        );
    }
}